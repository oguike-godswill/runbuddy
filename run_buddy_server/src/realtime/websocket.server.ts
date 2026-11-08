import { WebSocket, WebSocketServer } from 'ws';
import jwt from 'jsonwebtoken';
import { config } from '../config/env';
import { getDatabase } from '../database/client';
import { AuthenticatedUserPayload } from '../middleware/auth';

interface AuthenticatedSocket extends WebSocket {
  user?: AuthenticatedUserPayload;
  runId?: string;
  isAlive?: boolean;
}

export function setupRealtimeWebSocket(wss: WebSocketServer) {
  // Stale connection detector (every 10s per spec §9)
  const heartbeat = setInterval(() => {
    wss.clients.forEach((ws: WebSocket) => {
      const client = ws as AuthenticatedSocket;
      if (client.isAlive === false) {
        handleClientDisconnect(client, wss);
        return client.terminate();
      }
      client.isAlive = false;
      client.ping();
    });
  }, 10000);

  wss.on('close', () => clearInterval(heartbeat));

  wss.on('connection', (ws: AuthenticatedSocket) => {
    ws.isAlive = true;

    ws.on('pong', () => {
      ws.isAlive = true;
    });

    ws.on('message', async (data: string) => {
      try {
        const payload = JSON.parse(data.toString());
        await handleSocketEvent(ws, payload, wss);
      } catch (err: any) {
        ws.send(JSON.stringify({ eventType: 'run.error', error: err.message || 'Invalid JSON' }));
      }
    });

    ws.on('close', () => {
      handleClientDisconnect(ws, wss);
    });
  });
}

async function handleSocketEvent(ws: AuthenticatedSocket, message: any, wss: WebSocketServer) {
  const { eventType, token, runId } = message;

  // 1. Authenticate connection token
  if (!ws.user && token) {
    try {
      const decoded = jwt.verify(token, config.jwtAccessSecret) as AuthenticatedUserPayload;
      ws.user = decoded;
    } catch {
      return ws.send(JSON.stringify({ eventType: 'run.error', error: 'Authentication failed: invalid token' }));
    }
  }

  if (!ws.user) {
    return ws.send(JSON.stringify({ eventType: 'run.error', error: 'Unauthenticated socket' }));
  }

  const db = await getDatabase();

  switch (eventType) {
    case 'run.join': {
      if (!runId) return ws.send(JSON.stringify({ eventType: 'run.error', error: 'runId required' }));

      // Authorize membership per spec §9 & §16
      const participantCheck = await db.query(
        'SELECT role, status FROM run_participants WHERE run_id = $1 AND user_id = $2',
        [runId, ws.user.userId]
      );

      if (participantCheck.rowCount === 0) {
        return ws.send(JSON.stringify({ eventType: 'run.error', error: 'Unauthorized: not a participant of this run' }));
      }

      ws.runId = runId;
      await db.query(
        "UPDATE run_participants SET status = 'JOINED' WHERE run_id = $1 AND user_id = $2",
        [runId, ws.user.userId]
      );

      broadcastToRun(wss, runId, {
        eventType: 'run.participant_joined',
        userId: ws.user.userId,
        username: ws.user.username,
        timestamp: Date.now(),
      });
      break;
    }

    case 'run.ready': {
      if (!ws.runId) return;

      await db.query(
        "UPDATE run_participants SET status = 'READY' WHERE run_id = $1 AND user_id = $2",
        [ws.runId, ws.user.userId]
      );

      // Check if all participants are ready
      const allParts = await db.query(
        'SELECT user_id, status FROM run_participants WHERE run_id = $1',
        [ws.runId]
      );

      const allReady = allParts.rows.length >= 2 && allParts.rows.every((p: any) => p.status === 'READY');

      if (allReady) {
        await db.query("UPDATE runs SET status = 'ACTIVE', started_at = now() WHERE id = $1", [ws.runId]);
        broadcastToRun(wss, ws.runId, {
          eventType: 'run.countdown_start',
          countdownSeconds: 3,
        });
      } else {
        broadcastToRun(wss, ws.runId, {
          eventType: 'run.participant_ready',
          userId: ws.user.userId,
        });
      }
      break;
    }

    case 'run.location': {
      if (!ws.runId) return;
      const { latitude, longitude, speedMps, accuracyM, distanceKm, durationSeconds, averagePaceSeconds } = message;

      // Ephemeral relay to partner over WebSocket (NOT writing every raw tick to PostgreSQL per spec §1 & §9)
      relayToPartner(wss, ws, ws.runId, {
        eventType: 'run.partner_telemetry',
        senderId: ws.user.userId,
        latitude,
        longitude,
        speedMps,
        accuracyM,
        distanceKm,
        durationSeconds,
        averagePaceSeconds,
        timestamp: Date.now(),
      });
      break;
    }

    case 'run.pause': {
      if (!ws.runId) return;
      await db.query("UPDATE run_participants SET status = 'PAUSED' WHERE run_id = $1 AND user_id = $2", [ws.runId, ws.user.userId]);
      relayToPartner(wss, ws, ws.runId, {
        eventType: 'run.partner_paused',
        userId: ws.user.userId,
      });
      break;
    }

    case 'run.resume': {
      if (!ws.runId) return;
      await db.query("UPDATE run_participants SET status = 'RUNNING' WHERE run_id = $1 AND user_id = $2", [ws.runId, ws.user.userId]);
      relayToPartner(wss, ws, ws.runId, {
        eventType: 'run.partner_resumed',
        userId: ws.user.userId,
      });
      break;
    }

    case 'run.reaction': {
      if (!ws.runId || !message.emoji) return;
      relayToPartner(wss, ws, ws.runId, {
        eventType: 'run.reaction',
        senderId: ws.user.userId,
        emoji: message.emoji,
      });
      break;
    }

    case 'run.finish': {
      if (!ws.runId) return;
      const { finalDistanceKm, finalDurationSeconds, finalPaceSeconds } = message;

      // Authoritative finish persistence (spec §10 & §22)
      await db.query(
        `UPDATE run_participants 
         SET status = 'FINISHED', distance_km = $1, duration_seconds = $2, average_pace_seconds = $3, finished_at = now()
         WHERE run_id = $4 AND user_id = $5`,
        [finalDistanceKm || 0, finalDurationSeconds || 0, finalPaceSeconds || 0, ws.runId, ws.user.userId]
      );

      // Increment aggregate stats in runner_profiles
      await db.query(
        `UPDATE runner_profiles 
         SET total_runs = total_runs + 1,
             total_distance_km = total_distance_km + $1,
             total_duration_seconds = total_duration_seconds + $2,
             longest_run_km = GREATEST(longest_run_km, $1),
             updated_at = now()
         WHERE user_id = $3`,
        [finalDistanceKm || 0, finalDurationSeconds || 0, ws.user.userId]
      );

      relayToPartner(wss, ws, ws.runId, {
        eventType: 'run.partner_finished',
        userId: ws.user.userId,
      });

      // Check if all participants finished
      const allDone = await db.query(
        "SELECT status FROM run_participants WHERE run_id = $1 AND status != 'FINISHED'",
        [ws.runId]
      );
      if (allDone.rowCount === 0) {
        await db.query("UPDATE runs SET status = 'COMPLETED', ended_at = now() WHERE id = $1", [ws.runId]);
        broadcastToRun(wss, ws.runId, { eventType: 'run.all_completed' });
      }
      break;
    }
  }
}

async function handleClientDisconnect(ws: AuthenticatedSocket, wss: WebSocketServer) {
  if (ws.runId && ws.user) {
    const db = await getDatabase();
    await db.query(
      "UPDATE run_participants SET status = 'RECONNECTING' WHERE run_id = $1 AND user_id = $2 AND status != 'FINISHED'",
      [ws.runId, ws.user.userId]
    );

    relayToPartner(wss, ws, ws.runId, {
      eventType: 'run.partner_reconnecting',
      userId: ws.user.userId,
      timestamp: Date.now(),
    });
  }
}

function relayToPartner(wss: WebSocketServer, senderWs: AuthenticatedSocket, runId: string, payload: any) {
  wss.clients.forEach((client: WebSocket) => {
    const c = client as AuthenticatedSocket;
    if (c !== senderWs && c.runId === runId && c.readyState === WebSocket.OPEN) {
      c.send(JSON.stringify(payload));
    }
  });
}

function broadcastToRun(wss: WebSocketServer, runId: string, payload: any) {
  wss.clients.forEach((client: WebSocket) => {
    const c = client as AuthenticatedSocket;
    if (c.runId === runId && c.readyState === WebSocket.OPEN) {
      c.send(JSON.stringify(payload));
    }
  });
}


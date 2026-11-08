import express, { Response } from 'express';
import http from 'http';
import cors from 'cors';
import { WebSocketServer } from 'ws';
import { config } from './config/env';
import { getDatabase } from './database/client';
import { AuthService, authenticateToken, AuthenticatedRequest } from './middleware/auth';
import { setupRealtimeWebSocket } from './realtime/websocket.server';
import { LiveKitVoiceService } from './integrations/voice.service';

const app = express();
app.use(cors({ origin: config.corsOrigins }));
app.use(express.json());

const server = http.createServer(app);
const wss = new WebSocketServer({ server });
setupRealtimeWebSocket(wss);

// ----------------------------------------------------
// AUTH ENDPOINTS (Spec §13)
// ----------------------------------------------------

// 1. Register
app.post('/api/v1/auth/register', async (req, res) => {
  const { email, username, displayName, password, typicalPaceSeconds, typicalDistanceKm } = req.body;

  if (!email || !username || !displayName || !password) {
    return res.status(400).json({ error: 'email, username, displayName, and password are required' });
  }

  const db = await getDatabase();

  const existing = await db.query(
    'SELECT id FROM users WHERE LOWER(email) = LOWER($1) OR LOWER(username) = LOWER($2)',
    [email.trim(), username.trim()]
  );

  if (existing.rowCount > 0) {
    return res.status(409).json({ error: 'User with this email or username already exists' });
  }

  const passwordHash = await AuthService.hashPassword(password);
  const verifyCode = Math.floor(100000 + Math.random() * 900000).toString();

  const insertUser = await db.query(
    `INSERT INTO users (email, username, display_name, password_hash, verification_code)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, email, username, display_name, created_at`,
    [email.trim().toLowerCase(), username.trim().toLowerCase(), displayName.trim(), passwordHash, verifyCode]
  );

  const newUser = insertUser.rows[0];

  // Initialize runner profile per spec §12
  await db.query(
    `INSERT INTO runner_profiles (user_id, typical_distance_km, typical_pace_seconds)
     VALUES ($1, $2, $3)`,
    [newUser.id, typicalDistanceKm || 5.0, typicalPaceSeconds || 330]
  );

  // Verification code delivery (console print per user preference)
  console.log(`\n======================================================`);
  console.log(`[EMAIL VERIFICATION CODE] For: ${newUser.email}`);
  console.log(`>>> CODE: ${verifyCode} <<<`);
  console.log(`======================================================\n`);

  const accessToken = AuthService.generateAccessToken(newUser);
  const refreshToken = AuthService.generateRefreshToken();

  await db.query(
    `INSERT INTO sessions (user_id, refresh_token_hash, expires_at)
     VALUES ($1, $2, now() + interval '30 days')`,
    [newUser.id, refreshToken.hash]
  );

  return res.status(201).json({
    accessToken,
    refreshToken: refreshToken.token,
    user: newUser,
    verificationRequired: true,
  });
});

// 2. Login (Accepts either email or username)
app.post('/api/v1/auth/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email or username and password required' });
  }

  const cleanIdentifier = email.trim().replace(/^@/, '').toLowerCase();
  const db = await getDatabase();
  const result = await db.query(
    'SELECT id, email, username, display_name, password_hash FROM users WHERE LOWER(email) = $1 OR LOWER(username) = $1',
    [cleanIdentifier]
  );

  if (result.rowCount === 0) {
    return res.status(401).json({ error: 'Invalid email, username, or password' });
  }

  const user = result.rows[0];
  const valid = await AuthService.comparePassword(password, user.password_hash);
  if (!valid) {
    return res.status(401).json({ error: 'Invalid email, username, or password' });
  }

  const accessToken = AuthService.generateAccessToken(user);
  const refreshToken = AuthService.generateRefreshToken();

  await db.query(
    `INSERT INTO sessions (user_id, refresh_token_hash, expires_at)
     VALUES ($1, $2, now() + interval '30 days')`,
    [user.id, refreshToken.hash]
  );

  return res.json({
    accessToken,
    refreshToken: refreshToken.token,
    user: {
      id: user.id,
      email: user.email,
      username: user.username,
      displayName: user.display_name,
    },
  });
});

// Password Reset Endpoint
app.post('/api/v1/auth/reset-password', async (req, res) => {
  const { identifier, newPassword } = req.body;
  if (!identifier || !newPassword) {
    return res.status(400).json({ error: 'Email or username and new password are required' });
  }

  if (newPassword.trim().length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }

  const cleanId = identifier.trim().replace(/^@/, '').toLowerCase();
  const db = await getDatabase();
  const userRes = await db.query(
    'SELECT id, email, username FROM users WHERE LOWER(email) = $1 OR LOWER(username) = $1',
    [cleanId]
  );

  if (userRes.rowCount === 0) {
    return res.status(404).json({ error: 'No runner account found with that email or username' });
  }

  const user = userRes.rows[0];
  const newHash = await AuthService.hashPassword(newPassword.trim());
  await db.query(
    'UPDATE users SET password_hash = $1, updated_at = now() WHERE id = $2',
    [newHash, user.id]
  );

  return res.json({ success: true, message: 'Password reset successfully. You can now log in.' });
});

// 3. Verify Email
app.post('/api/v1/auth/verify', async (req, res) => {
  const { email, code } = req.body;
  const db = await getDatabase();
  const result = await db.query(
    'SELECT id, verification_code FROM users WHERE LOWER(email) = LOWER($1)',
    [email.trim()]
  );

  if (result.rowCount === 0 || result.rows[0].verification_code !== code) {
    return res.status(400).json({ error: 'Invalid verification code' });
  }

  await db.query(
    'UPDATE users SET email_verified_at = now(), verification_code = NULL WHERE id = $1',
    [result.rows[0].id]
  );

  return res.json({ success: true, message: 'Email verified successfully' });
});

// 4. Current User Profile
app.get('/api/v1/users/me', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  const db = await getDatabase();
  const userRes = await db.query(
    `SELECT u.id, u.email, u.username, u.display_name, u.avatar_url, u.email_verified_at,
            p.experience_level, p.typical_distance_km, p.typical_pace_seconds,
            p.total_runs, p.total_distance_km, p.total_duration_seconds, p.longest_run_km
     FROM users u
     LEFT JOIN runner_profiles p ON p.user_id = u.id
     WHERE u.id = $1`,
    [req.user!.userId]
  );

  if (userRes.rowCount === 0) return res.status(404).json({ error: 'User not found' });
  return res.json({ user: userRes.rows[0] });
});

// 5. Update Current User Profile
app.put('/api/v1/users/me', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  const { displayName, typicalPaceSeconds, typicalDistanceKm, experienceLevel } = req.body;
  const db = await getDatabase();
  const userId = req.user!.userId;

  if (displayName && typeof displayName === 'string' && displayName.trim().length > 0) {
    await db.query(
      `UPDATE users SET display_name = $1, updated_at = now() WHERE id = $2`,
      [displayName.trim(), userId]
    );
  }

  const updates: string[] = [];
  const params: any[] = [];
  let paramIdx = 1;

  if (typicalPaceSeconds !== undefined && !isNaN(Number(typicalPaceSeconds))) {
    updates.push(`typical_pace_seconds = $${paramIdx++}`);
    params.push(Math.round(Number(typicalPaceSeconds)));
  }
  if (typicalDistanceKm !== undefined && !isNaN(Number(typicalDistanceKm))) {
    updates.push(`typical_distance_km = $${paramIdx++}`);
    params.push(Number(typicalDistanceKm));
  }
  if (experienceLevel && ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'].includes(String(experienceLevel).toUpperCase())) {
    updates.push(`experience_level = $${paramIdx++}`);
    params.push(String(experienceLevel).toUpperCase());
  }

  if (updates.length > 0) {
    updates.push(`updated_at = now()`);
    params.push(userId);
    await db.query(
      `UPDATE runner_profiles SET ${updates.join(', ')} WHERE user_id = $${paramIdx}`,
      params
    );
  }

  const userRes = await db.query(
    `SELECT u.id, u.email, u.username, u.display_name, u.avatar_url, u.email_verified_at,
            p.experience_level, p.typical_distance_km, p.typical_pace_seconds,
            p.total_runs, p.total_distance_km, p.total_duration_seconds, p.longest_run_km
     FROM users u
     LEFT JOIN runner_profiles p ON p.user_id = u.id
     WHERE u.id = $1`,
    [userId]
  );

  return res.json({ success: true, user: userRes.rows[0] });
});

// ----------------------------------------------------
// FRIENDS & SOCIAL ENDPOINTS (Spec §13)
// ----------------------------------------------------

// List friends
app.get('/api/v1/friends', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  const db = await getDatabase();
  const myId = req.user!.userId;

  const result = await db.query(
    `SELECT u.id, u.email, u.username, u.display_name, u.avatar_url,
            p.typical_distance_km, p.typical_pace_seconds, p.total_runs
     FROM friendships f
     JOIN users u ON (u.id = CASE WHEN f.user_a_id = $1 THEN f.user_b_id ELSE f.user_a_id END)
     LEFT JOIN runner_profiles p ON p.user_id = u.id
     WHERE f.user_a_id = $1 OR f.user_b_id = $1`,
    [myId]
  );

  return res.json({ friends: result.rows });
});

// Search users
app.get('/api/v1/users/search', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  const query = (req.query.q as string || '').trim().toLowerCase();
  if (query.length < 2) return res.json({ users: [] });

  const db = await getDatabase();
  const result = await db.query(
    `SELECT id, username, display_name, avatar_url
     FROM users
     WHERE id != $1 AND (LOWER(username) LIKE $2 OR LOWER(display_name) LIKE $2)
     LIMIT 20`,
    [req.user!.userId, `%${query}%`]
  );

  return res.json({ users: result.rows });
});

// Send friend request
app.post('/api/v1/friends/requests', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  const { recipientId } = req.body;
  if (!recipientId || recipientId === req.user!.userId) {
    return res.status(400).json({ error: 'Invalid recipient ID' });
  }

  const db = await getDatabase();
  const insert = await db.query(
    `INSERT INTO friend_requests (requester_id, recipient_id, status)
     VALUES ($1, $2, 'PENDING')
     RETURNING id, status, created_at`,
    [req.user!.userId, recipientId]
  );

  // In-app notification for recipient
  await db.query(
    `INSERT INTO notifications (user_id, type, title, body, payload)
     VALUES ($1, 'FRIEND_REQUEST', 'New Friend Request', $2, $3)`,
    [recipientId, `${req.user!.username} sent you a running friend request.`, JSON.stringify({ requestId: insert.rows[0].id })]
  );

  return res.status(201).json({ request: insert.rows[0] });
});

// List pending incoming friend requests
app.get('/api/v1/friends/requests', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  const db = await getDatabase();
  const result = await db.query(
    `SELECT fr.id, fr.requester_id, fr.status, fr.created_at,
            u.username, u.display_name, u.avatar_url,
            p.typical_distance_km, p.typical_pace_seconds
     FROM friend_requests fr
     JOIN users u ON u.id = fr.requester_id
     LEFT JOIN runner_profiles p ON p.user_id = u.id
     WHERE fr.recipient_id = $1 AND fr.status = 'PENDING'
     ORDER BY fr.created_at DESC`,
    [req.user!.userId]
  );
  return res.json({ requests: result.rows });
});

// Accept friend request
app.post('/api/v1/friends/requests/:id/accept', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  const db = await getDatabase();
  const reqRes = await db.query(
    `SELECT * FROM friend_requests WHERE id = $1 AND recipient_id = $2 AND status = 'PENDING'`,
    [req.params.id, req.user!.userId]
  );

  if (reqRes.rowCount === 0) {
    return res.status(404).json({ error: 'Friend request not found or not pending' });
  }

  const fReq = reqRes.rows[0];
  const userA = fReq.requester_id < fReq.recipient_id ? fReq.requester_id : fReq.recipient_id;
  const userB = fReq.requester_id < fReq.recipient_id ? fReq.recipient_id : fReq.requester_id;

  await db.query(`UPDATE friend_requests SET status = 'ACCEPTED', responded_at = now() WHERE id = $1`, [fReq.id]);
  await db.query(
    `INSERT INTO friendships (user_a_id, user_b_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
    [userA, userB]
  );

  return res.json({ success: true, message: 'Friendship accepted' });
});

// ----------------------------------------------------
// RUN INVITATIONS & RUNS (Spec §13)
// ----------------------------------------------------

// Create Run Together Session + Invitation
app.post('/api/v1/runs', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  const { type, partnerId, goalDistanceKm } = req.body;
  const db = await getDatabase();
  const creatorId = req.user!.userId;

  const runInsert = await db.query(
    `INSERT INTO runs (type, status, creator_id, goal_distance_km)
     VALUES ($1, $2, $3, $4)
     RETURNING id, type, status, goal_distance_km, created_at`,
    [type || 'SOLO', type === 'TOGETHER' ? 'INVITED' : 'CREATED', creatorId, goalDistanceKm || 5.0]
  );

  const run = runInsert.rows[0];

  // Creator is joined
  await db.query(
    `INSERT INTO run_participants (run_id, user_id, role, status)
     VALUES ($1, $2, 'CREATOR', 'JOINED')`,
    [run.id, creatorId]
  );

  if (type === 'TOGETHER' && partnerId) {
    // Add partner participant row
    await db.query(
      `INSERT INTO run_participants (run_id, user_id, role, status)
       VALUES ($1, $2, 'PARTNER', 'JOINED')`,
      [run.id, partnerId]
    );

    // Create invitation with 10-minute expiry
    const invInsert = await db.query(
      `INSERT INTO run_invitations (run_id, sender_id, recipient_id, status, expires_at)
       VALUES ($1, $2, $3, 'PENDING', now() + interval '10 minutes')
       RETURNING id, expires_at`,
      [run.id, creatorId, partnerId]
    );

    // In-app notification
    await db.query(
      `INSERT INTO notifications (user_id, type, title, body, payload)
       VALUES ($1, 'RUN_INVITATION', 'Run Together Invitation', $2, $3)`,
      [partnerId, `${req.user!.username} invited you to run ${goalDistanceKm || 5} km together.`, JSON.stringify({ runId: run.id, invitationId: invInsert.rows[0].id })]
    );
  }

  // Voice Token Provisioning (LiveKit)
  let voiceTokenData = null;
  if (type === 'TOGETHER') {
    voiceTokenData = await LiveKitVoiceService.generateRoomToken(
      `run_${run.id}`,
      req.user!.userId,
      req.user!.username
    );
  }

  return res.status(201).json({
    run,
    voice: voiceTokenData,
  });
});

// Complete a Run (Authoritative persistence for Solo or Shared runs)
app.post('/api/v1/runs/complete', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  const { runId, type, distanceKm, durationSeconds, paceSeconds } = req.body;
  const db = await getDatabase();
  const userId = req.user!.userId;
  const dist = Number(distanceKm) || 0;
  const dur = Number(durationSeconds) || 0;
  const pace = Number(paceSeconds) || 0;

  const isUuid = typeof runId === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(runId);
  let actualRunId = isUuid ? runId : null;

  if (actualRunId) {
    const existing = await db.query('SELECT id FROM runs WHERE id = $1', [actualRunId]);
    if (existing.rowCount > 0) {
      await db.query(
        `UPDATE runs SET status = 'COMPLETED', ended_at = now() WHERE id = $1`,
        [actualRunId]
      );
      await db.query(
        `UPDATE run_participants 
         SET status = 'FINISHED', distance_km = $1, duration_seconds = $2, average_pace_seconds = $3, finished_at = now()
         WHERE run_id = $4 AND user_id = $5`,
        [dist, dur, pace, actualRunId, userId]
      );
    } else {
      actualRunId = null;
    }
  }

  if (!actualRunId) {
    // New run record (e.g. solo run)
    const runInsert = await db.query(
      `INSERT INTO runs (type, status, creator_id, goal_distance_km, started_at, ended_at)
       VALUES ($1, 'COMPLETED', $2, $3, now() - ($4 * interval '1 second'), now())
       RETURNING id`,
      [type || 'SOLO', userId, dist, dur]
    );
    actualRunId = runInsert.rows[0].id;
    await db.query(
      `INSERT INTO run_participants (run_id, user_id, role, status, distance_km, duration_seconds, average_pace_seconds, finished_at)
       VALUES ($1, $2, 'CREATOR', 'FINISHED', $3, $4, $5, now())`,
      [actualRunId, userId, dist, dur, pace]
    );
  }

  // Authoritative increment in runner_profiles
  await db.query(
    `UPDATE runner_profiles 
     SET total_runs = total_runs + 1,
         total_distance_km = total_distance_km + $1,
         total_duration_seconds = total_duration_seconds + $2,
         longest_run_km = GREATEST(longest_run_km, $1),
         updated_at = now()
     WHERE user_id = $3`,
    [dist, dur, userId]
  );

  const updatedStats = await db.query(
    `SELECT total_runs, total_distance_km, total_duration_seconds, longest_run_km, typical_pace_seconds
     FROM runner_profiles WHERE user_id = $1`,
    [userId]
  );

  return res.json({
    success: true,
    runId: actualRunId,
    stats: updatedStats.rows[0],
  });
});

// Run History List
app.get('/api/v1/runs', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  const db = await getDatabase();
  const userId = req.user!.userId;

  const runsRes = await db.query(
    `SELECT r.id, r.type, r.status, r.started_at, r.ended_at, r.created_at,
            COALESCE(rp.distance_km, r.goal_distance_km, 0) as distance_km,
            COALESCE(rp.duration_seconds, 0) as duration_seconds,
            COALESCE(rp.average_pace_seconds, 0) as average_pace_seconds
     FROM runs r
     LEFT JOIN run_participants rp ON rp.run_id = r.id AND rp.user_id = $1
     WHERE (r.creator_id = $1 OR rp.user_id = $1)
       AND (r.status = 'COMPLETED' OR rp.status = 'FINISHED')
     ORDER BY r.created_at DESC LIMIT 50`,
    [userId]
  );

  return res.json({ runs: runsRes.rows });
});

// Notifications Inbox (Spec §12 & §13)
app.get('/api/v1/notifications', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  const db = await getDatabase();
  const notifs = await db.query(
    `SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 30`,
    [req.user!.userId]
  );
  return res.json({ notifications: notifs.rows });
});

// Mark notifications read
app.post('/api/v1/notifications/read-all', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  const db = await getDatabase();
  await db.query(`UPDATE notifications SET read_at = now() WHERE user_id = $1`, [req.user!.userId]);
  return res.json({ success: true });
});

// Start server
server.listen(config.port, async () => {
  await getDatabase();
  console.log(`[RunBuddy Server] Authoritative REST & WebSocket engine listening on port ${config.port}`);
});

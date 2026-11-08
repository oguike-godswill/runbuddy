import { AccessToken } from 'livekit-server-sdk';
import { config } from '../config/env';

export interface VoiceTokenResult {
  token: string;
  roomName: string;
  serverUrl: string;
}

export class LiveKitVoiceService {
  static async generateRoomToken(roomName: string, participantIdentity: string, participantName: string): Promise<VoiceTokenResult> {
    const at = new AccessToken(config.voice.apiKey, config.voice.apiSecret, {
      identity: participantIdentity,
      name: participantName,
      ttl: '2h', // Short-lived room token per spec §11
    });

    at.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    const token = await at.toJwt();
    return {
      token,
      roomName,
      serverUrl: config.voice.livekitUrl,
    };
  }
}


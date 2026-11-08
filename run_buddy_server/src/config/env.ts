import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

export const config = {
  port: parseInt(process.env.PORT || '4000', 10),
  databaseUrl: process.env.DATABASE_URL || '',
  jwtAccessSecret: process.env.JWT_ACCESS_SECRET || 'runbuddy_access_dev_secret_key_2026',
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET || 'runbuddy_refresh_dev_secret_key_2026',
  corsOrigins: process.env.CORS_ORIGINS || '*',
  voice: {
    provider: process.env.VOICE_PROVIDER || 'livekit',
    livekitUrl: process.env.LIVEKIT_URL || 'wss://runbuddy-5y0irk2s.livekit.cloud',
    apiKey: process.env.LIVEKIT_API_KEY || 'APISEgkhWk6RbzB',
    apiSecret: process.env.LIVEKIT_API_SECRET || '5bdfzXdLH7BHy7fdzMN2gRA14AMghkpuaPomNZijbwX',
  },
};


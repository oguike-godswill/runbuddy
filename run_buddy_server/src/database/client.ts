import fs from 'fs';
import path from 'path';
import { Pool } from 'pg';
import { PGlite } from '@electric-sql/pglite';
import { config } from '../config/env';

export interface DatabaseClient {
  query<T = any>(sql: string, params?: any[]): Promise<{ rows: T[]; rowCount: number }>;
  exec(sql: string): Promise<void>;
}

class PGliteAdapter implements DatabaseClient {
  private pglite: PGlite;

  constructor(dirPath: string) {
    this.pglite = new PGlite(dirPath);
  }

  async query<T = any>(sql: string, params?: any[]): Promise<{ rows: T[]; rowCount: number }> {
    const res = await this.pglite.query(sql, params);
    return {
      rows: (res.rows as T[]) || [],
      rowCount: res.rows ? res.rows.length : 0,
    };
  }

  async exec(sql: string): Promise<void> {
    await this.pglite.exec(sql);
  }
}

class PgPoolAdapter implements DatabaseClient {
  private pool: Pool;

  constructor(connectionString: string) {
    this.pool = new Pool({ connectionString, ssl: { rejectUnauthorized: false } });
  }

  async query<T = any>(sql: string, params?: any[]): Promise<{ rows: T[]; rowCount: number }> {
    const res = await this.pool.query(sql, params);
    return {
      rows: (res.rows as T[]) || [],
      rowCount: res.rowCount || 0,
    };
  }

  async exec(sql: string): Promise<void> {
    await this.pool.query(sql);
  }
}

let dbInstance: DatabaseClient | null = null;
let initPromise: Promise<DatabaseClient> | null = null;

export async function getDatabase(): Promise<DatabaseClient> {
  if (dbInstance) return dbInstance;
  if (initPromise) return initPromise;

  initPromise = (async () => {
    let client: DatabaseClient;
    if (config.databaseUrl && config.databaseUrl.trim().length > 0) {
      console.log('[DB] Connecting to Remote PostgreSQL (Supabase)...');
      client = new PgPoolAdapter(config.databaseUrl);
    } else {
      const dataDir = path.resolve(__dirname, '../../.data/pglite');
      if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
      }
      console.log(`[DB] Using embedded disk-backed PostgreSQL (PGlite) at: ${dataDir}`);
      client = new PGliteAdapter(dataDir);
    }

    await runMigrations(client);
    dbInstance = client;
    return dbInstance;
  })();

  return initPromise;
}

async function runMigrations(db: DatabaseClient) {
  // Execute statements individually to ensure total compatibility
  const statements = [
    `CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email TEXT NOT NULL UNIQUE,
      username TEXT NOT NULL UNIQUE,
      display_name TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      avatar_url TEXT,
      email_verified_at TIMESTAMPTZ,
      verification_code TEXT,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );`,
    `CREATE TABLE IF NOT EXISTS runner_profiles (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      experience_level TEXT NOT NULL DEFAULT 'BEGINNER' CHECK (experience_level IN ('BEGINNER','INTERMEDIATE','ADVANCED')),
      typical_distance_km DECIMAL(8,3),
      typical_pace_seconds INTEGER,
      total_runs INTEGER NOT NULL DEFAULT 0,
      total_distance_km DECIMAL(10,3) NOT NULL DEFAULT 0,
      total_duration_seconds BIGINT NOT NULL DEFAULT 0,
      longest_run_km DECIMAL(8,3) NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );`,
    `CREATE TABLE IF NOT EXISTS sessions (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      refresh_token_hash TEXT NOT NULL,
      device_id TEXT,
      expires_at TIMESTAMPTZ NOT NULL,
      revoked_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      last_used_at TIMESTAMPTZ
    );`,
    `CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);`,
    `CREATE TABLE IF NOT EXISTS friend_requests (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','ACCEPTED','DECLINED','CANCELLED')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      responded_at TIMESTAMPTZ,
      CHECK (requester_id <> recipient_id)
    );`,
    `CREATE INDEX IF NOT EXISTS idx_fr_recipient ON friend_requests(recipient_id, status);`,
    `CREATE TABLE IF NOT EXISTS friendships (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_a_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      user_b_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      CHECK (user_a_id < user_b_id),
      UNIQUE (user_a_id, user_b_id)
    );`,
    `CREATE TABLE IF NOT EXISTS runs (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      type TEXT NOT NULL CHECK (type IN ('SOLO','TOGETHER')),
      status TEXT NOT NULL CHECK (status IN ('CREATED','INVITED','ACCEPTED','READY','ACTIVE','PAUSED','DECLINED','EXPIRED','CANCELLED','COMPLETED','ABANDONED')),
      creator_id UUID NOT NULL REFERENCES users(id),
      goal_distance_km DECIMAL(8,3),
      started_at TIMESTAMPTZ,
      ended_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );`,
    `CREATE TABLE IF NOT EXISTS run_participants (
      run_id UUID NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id),
      role TEXT NOT NULL CHECK (role IN ('CREATOR','PARTNER')),
      status TEXT NOT NULL DEFAULT 'JOINED' CHECK (status IN ('JOINED','READY','RUNNING','PAUSED','RECONNECTING','FINISHED','LEFT')),
      distance_km DECIMAL(8,3) NOT NULL DEFAULT 0,
      duration_seconds BIGINT NOT NULL DEFAULT 0,
      average_pace_seconds INTEGER,
      joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      finished_at TIMESTAMPTZ,
      PRIMARY KEY (run_id, user_id)
    );`,
    `CREATE INDEX IF NOT EXISTS idx_rp_user ON run_participants(user_id);`,
    `CREATE TABLE IF NOT EXISTS run_invitations (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      run_id UUID NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
      sender_id UUID NOT NULL REFERENCES users(id),
      recipient_id UUID NOT NULL REFERENCES users(id),
      status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','ACCEPTED','DECLINED','EXPIRED','CANCELLED')),
      expires_at TIMESTAMPTZ NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      responded_at TIMESTAMPTZ
    );`,
    `CREATE INDEX IF NOT EXISTS idx_inv_recipient ON run_invitations(recipient_id, status);`,
    `CREATE TABLE IF NOT EXISTS route_points (
      id BIGSERIAL PRIMARY KEY,
      run_id UUID NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id),
      latitude DOUBLE PRECISION NOT NULL,
      longitude DOUBLE PRECISION NOT NULL,
      altitude_m DOUBLE PRECISION,
      speed_mps DOUBLE PRECISION,
      accuracy_m DOUBLE PRECISION,
      recorded_at TIMESTAMPTZ NOT NULL
    );`,
    `CREATE INDEX IF NOT EXISTS idx_route_run_user ON route_points(run_id, user_id, recorded_at);`,
    `CREATE TABLE IF NOT EXISTS notifications (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      type TEXT NOT NULL CHECK (type IN ('FRIEND_REQUEST','FRIEND_REQUEST_ACCEPTED','RUN_INVITATION','RUN_INVITATION_ACCEPTED','RUN_INVITATION_DECLINED','RUN_READY','RUN_STARTED','RUN_COMPLETED')),
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      payload JSONB,
      read_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );`,
    `CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id, created_at DESC);`
  ];

  console.log('[DB] Executing table initializations sequentially...');
  for (const stmt of statements) {
    await db.exec(stmt);
  }

  // Pre-seed core runner accounts so login is always reliable
  const bcrypt = await import('bcryptjs');
  const defaultHash = await bcrypt.default.hash('password123', 10);
  await db.query(`
    INSERT INTO users (id, email, username, display_name, password_hash)
    VALUES 
      ('71979244-865d-42ba-a369-bdcce2c8c7eb', 'athlete@runbuddy.local', 'athlete', 'Alex Rivera', '${defaultHash}'),
      ('58d2e63d-9b59-4192-a027-f11b439ee6e6', 'lelasuace@gmail.com', 'dammy', 'Godswill', '${defaultHash}')
    ON CONFLICT (email) DO NOTHING
  `);
  await db.query(`
    INSERT INTO runner_profiles (user_id, typical_distance_km, typical_pace_seconds)
    VALUES 
      ('71979244-865d-42ba-a369-bdcce2c8c7eb', 5.0, 330),
      ('58d2e63d-9b59-4192-a027-f11b439ee6e6', 5.0, 330)
    ON CONFLICT (user_id) DO NOTHING
  `);

  console.log('[DB] All core tables and indexes created successfully.');
}

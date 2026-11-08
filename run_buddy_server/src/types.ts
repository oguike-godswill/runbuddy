export interface User {
  id: string;
  email: string;
  username: string;
  displayName: string;
  passwordHash: string;
  avatarUrl?: string;
  createdAt: Date;
}

export interface RunnerProfile {
  userId: string;
  typicalDistanceKm: number;
  typicalPaceSeconds: number;
  totalRuns: number;
  totalDistanceKm: number;
  totalDurationSeconds: number;
}

export interface FriendRequest {
  id: string;
  requesterId: string;
  recipientId: string;
  status: 'PENDING' | 'ACCEPTED' | 'DECLINED';
  createdAt: Date;
}

export interface Friendship {
  id: string;
  userAId: string;
  userBId: string;
  createdAt: Date;
}

export type RunType = 'SOLO' | 'TOGETHER';
export type RunStatus = 'CREATED' | 'INVITED' | 'ACCEPTED' | 'READY' | 'ACTIVE' | 'PAUSED' | 'COMPLETED' | 'ABANDONED';
export type ParticipantState = 'JOINED' | 'READY' | 'RUNNING' | 'PAUSED' | 'RECONNECTING' | 'FINISHED';

export interface RunParticipant {
  userId: string;
  state: ParticipantState;
  distanceKm: number;
  durationSeconds: number;
  averagePaceSeconds: number;
  lastLatitude?: number;
  lastLongitude?: number;
  lastHeartbeatAt: number;
}

export interface RunSession {
  id: string;
  type: RunType;
  status: RunStatus;
  creatorId: string;
  goalDistanceKm: number;
  startedAt?: Date;
  endedAt?: Date;
  participants: Map<string, RunParticipant>;
}


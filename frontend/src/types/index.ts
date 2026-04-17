export interface Task {
  taskId: string;
  title: string;
  completed: boolean;
  createdAt: string;
  hasImage?: boolean;
  userId?: string;
}

export interface User {
  email: string;
  idToken: string;
  accessToken: string;
  refreshToken: string;
}

export interface UploadProgress {
  taskId: string;
  progress: number;
}

export type TaskFilter = 'all' | 'active' | 'completed';

import type { Task } from '../types';
import { config } from './config';
import { AuthService } from './auth';

const API_BASE = config.apiEndpoint;

class ApiError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ApiError';
  }
}

const getAuthHeaders = (): Record<string, string> => {
  const token = AuthService.getIdToken();
  return {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
    'X-CloudFront-Domain': config.cloudFrontDomain,
  };
};

export const taskApi = {
  async getTasks(): Promise<Task[]> {
    const response = await fetch(`${API_BASE}/api/tasks`, {
      method: 'GET',
      headers: getAuthHeaders(),
    });

    if (!response.ok) {
      throw new ApiError('Failed to fetch tasks');
    }

    return response.json();
  },

  async createTask(title: string): Promise<Task> {
    const response = await fetch(`${API_BASE}/api/tasks`, {
      method: 'POST',
      headers: getAuthHeaders(),
      body: JSON.stringify({ title }),
    });

    if (!response.ok) {
      throw new ApiError('Failed to create task');
    }

    return response.json();
  },

  async updateTask(taskId: string, completed: boolean): Promise<void> {
    const response = await fetch(`${API_BASE}/api/tasks/${taskId}`, {
      method: 'PUT',
      headers: getAuthHeaders(),
      body: JSON.stringify({ completed }),
    });

    if (!response.ok) {
      throw new ApiError('Failed to update task');
    }
  },

  async deleteTask(taskId: string): Promise<void> {
    const response = await fetch(`${API_BASE}/api/tasks/${taskId}`, {
      method: 'DELETE',
      headers: getAuthHeaders(),
    });

    if (!response.ok) {
      throw new ApiError('Failed to delete task');
    }
  },

  async getUploadUrl(taskId: string): Promise<{ uploadURL: string }> {
    const response = await fetch(`${API_BASE}/api/upload-url`, {
      method: 'POST',
      headers: getAuthHeaders(),
      body: JSON.stringify({ taskId }),
    });

    if (!response.ok) {
      throw new ApiError('Failed to get upload URL');
    }

    return response.json();
  },

  async getSignedCookies(): Promise<void> {
    const response = await fetch(`${API_BASE}/api/get-access`, {
      method: 'GET',
      headers: {
        ...getAuthHeaders(),
        'X-CloudFront-Domain': config.cloudFrontDomain,
      },
      credentials: 'include',
    });

    if (!response.ok) {
      throw new ApiError('Failed to get signed cookies');
    }
  },

  getCloudFrontImageUrl(taskId: string, userId: string, isThumbnail: boolean = false): string {
    const imageName = isThumbnail ? 'thumbnail.png' : 'photo.png';
    return `https://${config.cloudFrontDomain}/users/${userId}/${taskId}/${imageName}`;
  },

  async uploadFile(uploadUrl: string, file: File, onProgress?: (progress: number) => void): Promise<void> {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();

      xhr.upload.onprogress = (event) => {
        if (event.lengthComputable && onProgress) {
          const percentComplete = (event.loaded / event.total) * 100;
          onProgress(percentComplete);
        }
      };

      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve();
        } else {
          reject(new Error('Failed to upload file'));
        }
      };

      xhr.onerror = () => reject(new Error('Upload failed'));

      xhr.open('PUT', uploadUrl, true);
      xhr.setRequestHeader('Content-Type', file.type);
      xhr.send(file);
    });
  },
};

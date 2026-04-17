import { useState, useCallback, useEffect } from 'react';
import type { Task } from '../types';
import { AuthService } from '../services/auth';
import { taskApi } from '../services/api';
import { useFileContext } from '../contexts/FileContext';

interface TaskItemProps {
  task: Task;
  onToggle: (taskId: string, completed: boolean) => void;
  onDelete: (taskId: string) => void;
  onImageClick: (url: string) => void;
  onUpload?: (taskId: string, file: File, onProgress: (progress: number) => void) => Promise<void>;
}

export function TaskItem({
  task,
  onToggle,
  onDelete,
  onImageClick,
  onUpload,
}: TaskItemProps) {
  const fileContext = useFileContext();
  const [displayUrl, setDisplayUrl] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const userId = AuthService.getCurrentUser()?.getUsername();

  const localBlobUrl = fileContext.blobs[task.taskId]?.blobUrl;

  const uploadProgress = fileContext.uploadProgress[task.taskId];
  const isUploading = uploadProgress !== undefined && uploadProgress < 100;

  const formattedDate = new Date(task.createdAt).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });

  useEffect(() => {
    if (!userId) return;

    const cacheKey = `${task.taskId}-thumb`;

    if (localBlobUrl) {
      setDisplayUrl(localBlobUrl);
      return;
    }

    if (!task.hasImage) return;

    const cachedUrl = fileContext.imageCache[cacheKey];
    if (cachedUrl) {
      setDisplayUrl(cachedUrl);
      return;
    }

    setIsLoading(true);
    const thumbUrl = taskApi.getCloudFrontImageUrl(task.taskId, userId, true);

    fetch(thumbUrl, { credentials: 'include' })
      .then(res => {
        if (!res.ok) throw new Error('Failed to fetch thumbnail');
        return res.blob();
      })
      .then(blob => {
        const objectUrl = URL.createObjectURL(blob);
        fileContext.setCachedImage(cacheKey, objectUrl);
        setDisplayUrl(objectUrl);
      })
      .catch(() => {
        setDisplayUrl(null);
      })
      .finally(() => {
        setIsLoading(false);
      });

    return () => {
      setIsLoading(false);
    };
  }, [task.hasImage, task.taskId, userId, localBlobUrl, fileContext]);

  const handleFileSelect = useCallback(
    async (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      if (!file || !task.taskId || !onUpload) return;

      try {
        await onUpload(task.taskId, file, () => {});
      } catch (err) {
        console.error('Upload failed:', err);
        alert('Upload failed. Please try again.');
      }
    },
    [task.taskId, onUpload]
  );

  const handleImageClick = useCallback(() => {
    if (!userId) return;


    if (localBlobUrl) {
      onImageClick(localBlobUrl);
      return;
    }

    if (!task.hasImage) return;

    const fullPhotoCacheKey = `${task.taskId}-full`;
    const cachedFullPhoto = fileContext.imageCache[fullPhotoCacheKey];
    if (cachedFullPhoto) {
      onImageClick(cachedFullPhoto);
      return;
    }

    const fullPhotoUrl = taskApi.getCloudFrontImageUrl(task.taskId, userId, false);
    fetch(fullPhotoUrl, { credentials: 'include' })
      .then(res => {
        if (!res.ok) throw new Error('Failed to fetch full photo');
        return res.blob();
      })
      .then(blob => {
        const objectUrl = URL.createObjectURL(blob);
        fileContext.setCachedImage(fullPhotoCacheKey, objectUrl);
        onImageClick(objectUrl);
      })
      .catch((err) => {
        console.error('Failed to load full image:', err);
        onImageClick(fullPhotoUrl);
      });
  }, [task.hasImage, task.taskId, userId, localBlobUrl, fileContext, onImageClick]);

  const thumbUrl = displayUrl;

  return (
    <li
      className={`task-item ${task.completed ? 'completed' : ''}`}
      style={{ opacity: isUploading ? 0.75 : 1 }}
    >
      <div className="task-row">
        <label className="task-checkbox-wrapper">
          <input
            type="checkbox"
            checked={task.completed}
            onChange={(e) => onToggle(task.taskId, e.target.checked)}
            disabled={isUploading}
          />
          <span className="checkmark"></span>
        </label>

        <div className="task-content">
          <div className="task-main">
            <span className={`task-title ${task.completed ? 'completed' : ''}`}>
              {task.title}
            </span>
            <span className="task-date">{formattedDate}</span>
          </div>

          <div className="task-actions-row">
            {isUploading && (
              <div className="progress-bar">
                <div
                  className="progress-fill"
                  style={{ width: `${uploadProgress || 0}%` }}
                />
              </div>
            )}

            {thumbUrl && !isUploading && (
              <div
                className="task-image-thumb"
                onClick={handleImageClick}
                style={{ opacity: isLoading ? 0.5 : 1 }}
              >
                <img
                  src={thumbUrl}
                  alt="Task"
                  loading="lazy"
                  crossOrigin="use-credentials"
                  onError={(e) => {
                    (e.target as HTMLImageElement).style.display = 'none';
                  }}
                />
                {isLoading && <span className="loading-indicator">...</span>}
              </div>
            )}

            <label className="task-upload-btn">
              <input
                type="file"
                accept=".png,.jpg,.jpeg"
                onChange={handleFileSelect}
                disabled={isUploading}
              />
              <span>{isUploading ? 'Uploading...' : 'Upload'}</span>
            </label>

            <button
              onClick={() => onDelete(task.taskId)}
              disabled={isUploading}
              className="task-delete-btn"
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </li>
  );
}

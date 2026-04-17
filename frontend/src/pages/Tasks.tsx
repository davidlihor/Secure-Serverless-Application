import { useState, useEffect, useMemo, useCallback } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import type { Task, TaskFilter } from '../types';
import { taskApi } from '../services/api';
import { useFileContext } from '../contexts/FileContext';
import { TaskForm } from '../components/TaskForm';
import { TaskFilters } from '../components/TaskFilters';
import { TaskItem } from '../components/TaskItem';
import { DeleteModal } from '../components/DeleteModal';
import { ImageModal } from '../components/ImageModal';

const TASKS_QUERY_KEY = ['tasks'];

export function Tasks() {
  const queryClient = useQueryClient();
  const fileContext = useFileContext();
  const [filter, setFilter] = useState<TaskFilter>('all');
  const [deleteTaskId, setDeleteTaskId] = useState<string | null>(null);
  const [previewImage, setPreviewImage] = useState<string | null>(null);

  useEffect(() => {
    taskApi.getSignedCookies().catch(console.error);
  }, []);

  const clearTaskBlob = useCallback((taskId: string) => {
    fileContext.clearBlob(taskId);
    fileContext.clearUploadProgress(taskId);
  }, [fileContext]);

  const { data: tasks = [], isLoading } = useQuery({
    queryKey: TASKS_QUERY_KEY,
    queryFn: taskApi.getTasks,
    staleTime: 30000,
  });

  const createMutation = useMutation({
    mutationFn: taskApi.createTask,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: TASKS_QUERY_KEY }),
  });

  const updateMutation = useMutation({
    mutationFn: ({ taskId, completed }: { taskId: string; completed: boolean }) =>
      taskApi.updateTask(taskId, completed),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: TASKS_QUERY_KEY }),
  });

  const deleteMutation = useMutation({
    mutationFn: taskApi.deleteTask,
    onMutate: async (taskId) => {
      await queryClient.cancelQueries({ queryKey: TASKS_QUERY_KEY });
      const previousTasks = queryClient.getQueryData<Task[]>(TASKS_QUERY_KEY);
      queryClient.setQueryData<Task[]>(TASKS_QUERY_KEY, (old) =>
        (old || []).filter((t) => t.taskId !== taskId)
      );
      clearTaskBlob(taskId);
      setDeleteTaskId(null);
      return { previousTasks };
    },
    onError: (_err, _taskId, context) => {
      queryClient.setQueryData(TASKS_QUERY_KEY, context?.previousTasks);
    },
  });

  const handleUpload = useCallback(
    async (taskId: string, file: File, onProgress: (progress: number) => void) => {
      fileContext.storeBlob(taskId, file);
      fileContext.setUploadProgress(taskId, 0);

      try {
        const { uploadURL } = await taskApi.getUploadUrl(taskId);
        await taskApi.uploadFile(uploadURL, file, (progress) => {
          fileContext.setUploadProgress(taskId, progress);
          onProgress(progress);
        });
        fileContext.setUploadProgress(taskId, 100);
        queryClient.invalidateQueries({ queryKey: TASKS_QUERY_KEY });
      } catch (err) {
        console.error('Upload failed:', err);
        fileContext.clearBlob(taskId);
        fileContext.clearUploadProgress(taskId);
        throw err;
      }
    },
    [queryClient, fileContext]
  );

  const filteredTasks = useMemo(() => {
    switch (filter) {
      case 'active':
        return tasks.filter((t) => !t.completed);
      case 'completed':
        return tasks.filter((t) => t.completed);
      default:
        return tasks;
    }
  }, [tasks, filter]);

  const taskCounts = useMemo(() => ({
    all: tasks.length,
    active: tasks.filter((t) => !t.completed).length,
    completed: tasks.filter((t) => t.completed).length,
  }), [tasks]);

  const handleAddTask = useCallback(
    (title: string) => createMutation.mutate(title),
    [createMutation]
  );

  const handleToggleTask = useCallback(
    (taskId: string, completed: boolean) =>
      updateMutation.mutate({ taskId, completed }),
    [updateMutation]
  );

  const handleDeleteTask = useCallback((taskId: string) => {
    setDeleteTaskId(taskId);
  }, []);

  const handleConfirmDelete = useCallback(() => {
    if (deleteTaskId) {
      deleteMutation.mutate(deleteTaskId);
    }
  }, [deleteTaskId, deleteMutation]);

  if (isLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--text-muted)' }}>
        Loading tasks...
      </div>
    );
  }

  return (
    <div>
      <TaskForm onSubmit={handleAddTask} loading={createMutation.isPending} />

      <TaskFilters
        currentFilter={filter}
        onFilterChange={setFilter}
        counts={taskCounts}
      />

      {filteredTasks.length === 0 ? (
        <div className="empty-state">
          {filter === 'all'
            ? 'No tasks yet. Add one above!'
            : `No ${filter} tasks.`}
        </div>
      ) : (
        <ul className="task-list">
          {filteredTasks.map((task) => (
            <TaskItem
              key={task.taskId}
              task={task}
              onToggle={handleToggleTask}
              onDelete={handleDeleteTask}
              onImageClick={setPreviewImage}
              onUpload={handleUpload}
            />
          ))}
        </ul>
      )}

      <DeleteModal
        isOpen={!!deleteTaskId}
        onClose={() => setDeleteTaskId(null)}
        onConfirm={handleConfirmDelete}
        loading={deleteMutation.isPending}
      />

      <ImageModal
        isOpen={!!previewImage}
        onClose={() => setPreviewImage(null)}
        imageUrl={previewImage}
      />
    </div>
  );
}

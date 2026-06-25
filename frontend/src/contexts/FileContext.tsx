import { createContext, useContext, useCallback, useState } from 'react';

interface FileCacheEntry {
  blobUrl: string;
  file?: File;
}

interface FileContextType {
  blobs: Record<string, FileCacheEntry>;
  storeBlob: (taskId: string, file: File) => string;
  clearBlob: (taskId: string) => void;
  imageCache: Record<string, string>;
  setCachedImage: (cacheKey: string, blobUrl: string) => void;
  uploadProgress: Record<string, number>;
  setUploadProgress: (taskId: string, progress: number) => void;
  clearUploadProgress: (taskId: string) => void;
}

const FileContext = createContext<FileContextType | null>(null);

export function FileProvider({ children }: { children: React.ReactNode }) {
  const [blobs, setBlobs] = useState<Record<string, FileCacheEntry>>({});
  const [imageCache, setImageCache] = useState<Record<string, string>>({});
  const [uploadProgress, setUploadProgressState] = useState<Record<string, number>>({});

  const storeBlob = useCallback((taskId: string, file: File): string => {
    const oldEntry = blobs[taskId];
    if (oldEntry?.blobUrl) {
      URL.revokeObjectURL(oldEntry.blobUrl);
    }
    const blobUrl = URL.createObjectURL(file);
    setBlobs(prev => ({ ...prev, [taskId]: { blobUrl, file } }));
    return blobUrl;
  }, [blobs]);

  const clearBlob = useCallback((taskId: string) => {
    const entry = blobs[taskId];
    if (entry?.blobUrl) {
      URL.revokeObjectURL(entry.blobUrl);
    }
    setBlobs(prev => {
      const next = { ...prev };
      delete next[taskId];
      return next;
    });
  }, [blobs]);

  const setCachedImage = useCallback((cacheKey: string, blobUrl: string) => {
    setImageCache(prev => ({ ...prev, [cacheKey]: blobUrl }));
  }, []);

  const setUploadProgress = useCallback((taskId: string, progress: number) => {
    setUploadProgressState(prev => ({ ...prev, [taskId]: progress }));
  }, []);

  const clearUploadProgress = useCallback((taskId: string) => {
    setUploadProgressState(prev => {
      const next = { ...prev };
      delete next[taskId];
      return next;
    });
  }, []);

  return (
    <FileContext.Provider value={{
      blobs,
      storeBlob,
      clearBlob,
      imageCache,
      setCachedImage,
      uploadProgress,
      setUploadProgress,
      clearUploadProgress,
    }}>
      {children}
    </FileContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useFileContext() {
  const context = useContext(FileContext);
  if (!context) {
    throw new Error('useFileContext must be used within FileProvider');
  }
  return context;
}

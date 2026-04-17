import type { TaskFilter } from '../types';

interface TaskFiltersProps {
  currentFilter: TaskFilter;
  onFilterChange: (filter: TaskFilter) => void;
  counts: { all: number; active: number; completed: number };
}

export function TaskFilters({ currentFilter, onFilterChange, counts }: TaskFiltersProps) {
  const filters: { key: TaskFilter; label: string }[] = [
    { key: 'all', label: `All (${counts.all})` },
    { key: 'active', label: `Active (${counts.active})` },
    { key: 'completed', label: `Completed (${counts.completed})` },
  ];

  return (
    <div className="task-filters">
      {filters.map(({ key, label }) => (
        <button
          key={key}
          onClick={() => onFilterChange(key)}
          className={`filter-btn ${currentFilter === key ? 'active' : ''}`}
        >
          {label}
        </button>
      ))}
    </div>
  );
}

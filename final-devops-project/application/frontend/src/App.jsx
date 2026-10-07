import { useCallback, useEffect, useState } from 'react';
import { api } from './api.js';
import StatsBar from './components/StatsBar.jsx';
import TaskForm from './components/TaskForm.jsx';
import TaskList from './components/TaskList.jsx';

const STATUS_FILTERS = [
  { value: '', label: 'All' },
  { value: 'todo', label: 'To do' },
  { value: 'in_progress', label: 'In progress' },
  { value: 'done', label: 'Done' },
];

export default function App() {
  const [tasks, setTasks] = useState([]);
  const [stats, setStats] = useState(null);
  const [statusFilter, setStatusFilter] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const refresh = useCallback(async () => {
    try {
      const [list, summary] = await Promise.all([
        api.listTasks({ status: statusFilter }),
        api.stats(),
      ]);
      setTasks(list);
      setStats(summary);
      setError('');
    } catch (err) {
      setError(`Could not reach the API: ${err.message}`);
    } finally {
      setLoading(false);
    }
  }, [statusFilter]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const run = async (action) => {
    try {
      await action();
      await refresh();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="page">
      <header className="header">
        <div>
          <h1>TaskFlow</h1>
          <p className="subtitle">Plan it, track it, ship it.</p>
        </div>
        <StatsBar stats={stats} />
      </header>

      <main className="layout">
        <section className="card">
          <h2>New task</h2>
          <TaskForm onCreate={(task) => run(() => api.createTask(task))} />
        </section>

        <section className="card">
          <div className="list-header">
            <h2>Tasks</h2>
            <div className="filters" role="tablist" aria-label="Filter by status">
              {STATUS_FILTERS.map((f) => (
                <button
                  key={f.value || 'all'}
                  type="button"
                  role="tab"
                  aria-selected={statusFilter === f.value}
                  className={statusFilter === f.value ? 'chip chip-active' : 'chip'}
                  onClick={() => setStatusFilter(f.value)}
                >
                  {f.label}
                </button>
              ))}
            </div>
          </div>

          {error && (
            <p className="error" role="alert">
              {error}
            </p>
          )}
          {loading ? (
            <p className="muted">Loading tasks...</p>
          ) : (
            <TaskList
              tasks={tasks}
              onStatus={(id, status) => run(() => api.updateTask(id, { status }))}
              onDelete={(id) => run(() => api.deleteTask(id))}
            />
          )}
        </section>
      </main>

      <footer className="footer">
        TaskFlow - DevOps final project by Bhuvanesh M S (24bcs10134)
      </footer>
    </div>
  );
}

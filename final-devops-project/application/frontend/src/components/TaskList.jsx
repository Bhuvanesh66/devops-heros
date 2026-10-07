const NEXT_STATUS = { todo: 'in_progress', in_progress: 'done', done: 'todo' };
const NEXT_LABEL = { todo: 'Start', in_progress: 'Complete', done: 'Reopen' };
const STATUS_LABEL = { todo: 'To do', in_progress: 'In progress', done: 'Done' };

function isOverdue(task) {
  if (!task.due_date || task.status === 'done') return false;
  const today = new Date().toISOString().slice(0, 10);
  return task.due_date < today;
}

export default function TaskList({ tasks, onStatus, onDelete }) {
  if (tasks.length === 0) {
    return <p className="muted">No tasks here yet. Add one on the left.</p>;
  }
  return (
    <ul className="tasks">
      {tasks.map((task) => (
        <li key={task.id} className={`task task-${task.status}`}>
          <div className="task-main">
            <label className="check">
              <input
                type="checkbox"
                checked={task.status === 'done'}
                onChange={() => onStatus(task.id, task.status === 'done' ? 'todo' : 'done')}
                aria-label={`Mark "${task.title}" as ${task.status === 'done' ? 'not done' : 'done'}`}
              />
              <span className="task-title">{task.title}</span>
            </label>
            {task.description && <p className="task-desc">{task.description}</p>}
            <div className="task-meta">
              <span className={`badge badge-${task.priority}`}>{task.priority}</span>
              <span className="badge badge-status">{STATUS_LABEL[task.status]}</span>
              {task.due_date && (
                <span className={isOverdue(task) ? 'due overdue' : 'due'}>
                  due {task.due_date}
                </span>
              )}
            </div>
          </div>
          <div className="task-actions">
            <button type="button" onClick={() => onStatus(task.id, NEXT_STATUS[task.status])}>
              {NEXT_LABEL[task.status]}
            </button>
            <button type="button" className="danger" onClick={() => onDelete(task.id)}>
              Delete
            </button>
          </div>
        </li>
      ))}
    </ul>
  );
}

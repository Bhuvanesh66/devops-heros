// All calls go to the same origin under /api. nginx (container) or the Vite dev
// server proxies them to the FastAPI backend, so the UI never needs to know
// where the backend lives and no CORS setup is required.
const BASE = '/api';

async function request(path, options = {}) {
  const response = await fetch(`${BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (!response.ok) {
    let detail = `${response.status} ${response.statusText}`;
    try {
      const body = await response.json();
      if (typeof body.detail === 'string') detail = body.detail;
      else if (Array.isArray(body.detail)) detail = body.detail.map((d) => d.msg).join('; ');
    } catch {
      // body was not JSON; keep the status text
    }
    throw new Error(detail);
  }
  return response.status === 204 ? null : response.json();
}

export const api = {
  listTasks: (filters = {}) => {
    const params = new URLSearchParams(
      Object.entries(filters).filter(([, value]) => value),
    ).toString();
    return request(`/tasks${params ? `?${params}` : ''}`);
  },
  createTask: (task) => request('/tasks', { method: 'POST', body: JSON.stringify(task) }),
  updateTask: (id, changes) =>
    request(`/tasks/${id}`, { method: 'PUT', body: JSON.stringify(changes) }),
  deleteTask: (id) => request(`/tasks/${id}`, { method: 'DELETE' }),
  stats: () => request('/stats'),
};

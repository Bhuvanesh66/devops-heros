import { useState } from 'react';

const EMPTY = { title: '', description: '', priority: 'medium', due_date: '' };

export default function TaskForm({ onCreate }) {
  const [form, setForm] = useState(EMPTY);
  const [saving, setSaving] = useState(false);

  const update = (field) => (event) => setForm({ ...form, [field]: event.target.value });

  const submit = async (event) => {
    event.preventDefault();
    if (!form.title.trim()) return;
    setSaving(true);
    await onCreate({
      title: form.title.trim(),
      description: form.description.trim() || null,
      priority: form.priority,
      due_date: form.due_date || null,
    });
    setSaving(false);
    setForm(EMPTY);
  };

  return (
    <form className="form" onSubmit={submit}>
      <label>
        Title
        <input
          value={form.title}
          onChange={update('title')}
          placeholder="e.g. Add an HPA for the backend"
          maxLength={200}
          required
        />
      </label>
      <label>
        Description
        <textarea
          value={form.description}
          onChange={update('description')}
          rows={3}
          maxLength={2000}
          placeholder="Optional details"
        />
      </label>
      <div className="form-row">
        <label>
          Priority
          <select value={form.priority} onChange={update('priority')}>
            <option value="low">Low</option>
            <option value="medium">Medium</option>
            <option value="high">High</option>
          </select>
        </label>
        <label>
          Due date
          <input type="date" value={form.due_date} onChange={update('due_date')} />
        </label>
      </div>
      <button className="primary" type="submit" disabled={saving || !form.title.trim()}>
        {saving ? 'Adding...' : 'Add task'}
      </button>
    </form>
  );
}

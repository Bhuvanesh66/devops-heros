export default function StatsBar({ stats }) {
  if (!stats) return null;
  const items = [
    { label: 'Total', value: stats.total },
    { label: 'To do', value: stats.todo },
    { label: 'In progress', value: stats.in_progress },
    { label: 'Done', value: stats.done },
    { label: 'High priority open', value: stats.high_priority_open, accent: true },
  ];
  return (
    <dl className="stats">
      {items.map((item) => (
        <div key={item.label} className={item.accent ? 'stat stat-accent' : 'stat'}>
          <dt>{item.label}</dt>
          <dd>{item.value}</dd>
        </div>
      ))}
    </dl>
  );
}

import React from 'react';

function formatSignalValue(value) {
  return typeof value === 'object' ? JSON.stringify(value) : String(value);
}

export default function InsightCard({ insight }) {
  if (!insight) return null;

  const signalEntries = insight.signals ? Object.entries(insight.signals) : [];
  const highlights = insight.insights || [];

  return (
    <div className="card insight-card">
      <div className="insight-card__header">
        <div>
          <span className="insight-card__eyebrow">Insight snapshot</span>
          <span className="insight-card__period">{insight.period_start} — {insight.period_end}</span>
        </div>
        <span className="badge badge--info">{insight.frequency}</span>
      </div>

      <div className="insight-card__summary">
        <div className="insight-card__stat">
          <span className="insight-card__stat-label">Signals</span>
          <strong className="insight-card__stat-value">{signalEntries.length}</strong>
        </div>
        <div className="insight-card__stat">
          <span className="insight-card__stat-label">Highlights</span>
          <strong className="insight-card__stat-value">{highlights.length}</strong>
        </div>
      </div>

      {signalEntries.length > 0 && (
        <div className="insight-card__section insight-card__signals">
          <div className="insight-card__section-title">Signals</div>
          <ul>
            {signalEntries.map(([key, value]) => (
              <li key={key} className="insight-card__signal-item">
                <span className="insight-card__signal-label">{key}</span>
                <span className="insight-card__signal-value">{formatSignalValue(value)}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
      {highlights.length > 0 && (
        <div className="insight-card__section insight-card__list">
          <div className="insight-card__section-title">Highlights</div>
          <ul>
            {highlights.map((item, idx) => (
              <li key={idx}>{item}</li>
            ))}
          </ul>
        </div>
      )}
      {insight.generated_at && (
        <div className="insight-card__date text-muted">
          Updated {new Date(insight.generated_at).toLocaleString()}
        </div>
      )}
    </div>
  );
}

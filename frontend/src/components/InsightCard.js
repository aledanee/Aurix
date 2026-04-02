import React from 'react';

export default function InsightCard({ insight }) {
  if (!insight) return null;

  return (
    <div className="card insight-card">
      <div className="insight-card__header">
        <span className="insight-card__period">{insight.period}</span>
        <span className="badge badge--info">{insight.frequency}</span>
      </div>
      {insight.signals && (
        <div className="insight-card__signals">
          <strong>Signals:</strong>
          <ul>
            {Object.entries(insight.signals).map(([key, value]) => (
              <li key={key}>
                <span className="text-muted">{key}:</span>{' '}
                {typeof value === 'object' ? JSON.stringify(value) : String(value)}
              </li>
            ))}
          </ul>
        </div>
      )}
      {insight.insights && insight.insights.length > 0 && (
        <div className="insight-card__list">
          <strong>Insights:</strong>
          <ul>
            {insight.insights.map((item, idx) => (
              <li key={idx}>{item}</li>
            ))}
          </ul>
        </div>
      )}
      {insight.created_at && (
        <div className="insight-card__date text-muted">
          {new Date(insight.created_at).toLocaleString()}
        </div>
      )}
    </div>
  );
}

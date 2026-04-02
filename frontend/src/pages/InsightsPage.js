import React, { useEffect, useState, useCallback } from 'react';
import { getInsights } from '../api/client';
import InsightCard from '../components/InsightCard';

export default function InsightsPage() {
  const [insights, setInsights] = useState([]);
  const [nextCursor, setNextCursor] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const insightState = loading ? 'Generating' : nextCursor ? 'More snapshots' : 'Current';

  const loadMore = useCallback(async (cursor) => {
    setLoading(true);
    setError(null);
    try {
      const data = await getInsights(cursor, 10);
      setInsights((prev) =>
        cursor ? [...prev, ...data.items] : data.items
      );
      setNextCursor(data.next_cursor || null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadMore(null);
  }, [loadMore]);

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <p className="page-kicker">Intelligence</p>
          <h1 className="page-title">Insights</h1>
          <p className="page-subtitle">
            Read the latest generated summaries, extracted signals, and product-facing market
            context.
          </p>
        </div>

        <div className="page-chip-group">
          <div className="page-chip page-chip--accent">
            <span className="page-chip__label">Snapshots</span>
            <strong className="page-chip__value">{insights.length}</strong>
          </div>
          <div className="page-chip">
            <span className="page-chip__label">Status</span>
            <strong className="page-chip__value">{insightState}</strong>
          </div>
        </div>
      </div>

      {error && <div className="alert alert--error">{error}</div>}

      <div className="card surface-card surface-card--accent">
        <div className="surface-header">
          <p className="surface-kicker">How to read this</p>
          <h2 className="surface-title">Signals first, highlights second.</h2>
          <p className="surface-copy">
            Each snapshot packages structured signal values with short product-oriented takeaways
            so you can review generated intelligence quickly.
          </p>
        </div>
      </div>

      {insights.length === 0 && !loading && (
        <div className="card empty-state">
          <p className="empty-state__eyebrow">Insights</p>
          <h3 className="empty-state__title">No generated snapshots yet</h3>
          <p className="empty-state__copy">
            New market intelligence cards will appear here once the insight pipeline publishes data.
          </p>
        </div>
      )}

      <div className="insight-grid">
        {insights.map((insight) => (
          <InsightCard key={insight.id} insight={insight} />
        ))}
      </div>

      {loading && <div className="spinner" />}

      {nextCursor && !loading && (
        <div className="load-more">
          <button
            className="btn btn--secondary"
            onClick={() => loadMore(nextCursor)}
          >
            Load More
          </button>
        </div>
      )}
    </div>
  );
}

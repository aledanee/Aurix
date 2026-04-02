import React, { useEffect, useState, useCallback } from 'react';
import { getInsights } from '../api/client';
import InsightCard from '../components/InsightCard';

export default function InsightsPage() {
  const [insights, setInsights] = useState([]);
  const [nextCursor, setNextCursor] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const loadMore = useCallback(async (cursor) => {
    setLoading(true);
    setError(null);
    try {
      const data = await getInsights(cursor, 10);
      setInsights((prev) =>
        cursor ? [...prev, ...data.snapshots] : data.snapshots
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
      <h1 className="page-title">AI Insights</h1>

      {error && <div className="alert alert--error">{error}</div>}

      {insights.length === 0 && !loading && (
        <p className="text-muted">No insights available yet.</p>
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

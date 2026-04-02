import React, { useEffect, useState, useCallback } from 'react';
import { getTransactions } from '../api/client';
import TransactionList from '../components/TransactionList';

export default function TransactionsPage() {
  const [transactions, setTransactions] = useState([]);
  const [nextCursor, setNextCursor] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const syncState = loading ? 'Syncing' : nextCursor ? 'More available' : 'Up to date';

  const loadMore = useCallback(async (cursor) => {
    setLoading(true);
    setError(null);
    try {
      const data = await getTransactions(cursor, 20);
      setTransactions((prev) =>
        cursor ? [...prev, ...data.transactions] : data.transactions
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
          <p className="page-kicker">History</p>
          <h1 className="page-title">Transactions</h1>
          <p className="page-subtitle">
            Inspect executed trades, recorded fees, and settlement outcomes in one running ledger.
          </p>
        </div>

        <div className="page-chip-group">
          <div className="page-chip page-chip--accent">
            <span className="page-chip__label">Loaded</span>
            <strong className="page-chip__value">{transactions.length}</strong>
          </div>
          <div className="page-chip">
            <span className="page-chip__label">Status</span>
            <strong className="page-chip__value">{syncState}</strong>
          </div>
        </div>
      </div>

      {error && <div className="alert alert--error">{error}</div>}

      <div className="card surface-card surface-card--subtle">
        <div className="surface-header">
          <p className="surface-kicker">Ledger summary</p>
          <h2 className="surface-title">Every completed trade stays visible here.</h2>
          <p className="surface-copy">
            Review timing, direction, quote, gross amount, and fee impact without leaving the
            product shell.
          </p>
        </div>
      </div>

      <TransactionList transactions={transactions} />

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

      {!loading && !nextCursor && transactions.length > 0 && (
        <p className="table-footer-note">All transactions loaded.</p>
      )}
    </div>
  );
}

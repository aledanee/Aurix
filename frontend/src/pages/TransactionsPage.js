import React, { useEffect, useState, useCallback } from 'react';
import { getTransactions } from '../api/client';
import TransactionList from '../components/TransactionList';

export default function TransactionsPage() {
  const [transactions, setTransactions] = useState([]);
  const [nextCursor, setNextCursor] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

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
      <h1 className="page-title">Transactions</h1>

      {error && <div className="alert alert--error">{error}</div>}

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
        <p className="text-muted text-center">All transactions loaded.</p>
      )}
    </div>
  );
}

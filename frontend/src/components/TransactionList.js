import React from 'react';

function formatEur(cents) {
  const euros = Number(cents) / 100;
  return new Intl.NumberFormat('en-EU', {
    style: 'currency',
    currency: 'EUR',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(euros);
}

function formatDate(iso) {
  const d = new Date(iso);
  return d.toLocaleDateString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export default function TransactionList({ transactions }) {
  if (!transactions || transactions.length === 0) {
    return <p className="text-muted">No transactions yet.</p>;
  }

  return (
    <div className="table-responsive">
      <table className="table">
        <thead>
          <tr>
            <th>Date</th>
            <th>Type</th>
            <th>Grams</th>
            <th>Price/gram</th>
            <th>Gross EUR</th>
            <th>Fee EUR</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {transactions.map((txn) => (
            <tr key={txn.id}>
              <td>{formatDate(txn.created_at)}</td>
              <td>
                <span
                  className={`badge ${
                    txn.type === 'buy' ? 'badge--success' : 'badge--danger'
                  }`}
                >
                  {txn.type.toUpperCase()}
                </span>
              </td>
              <td>{parseFloat(txn.gold_grams).toFixed(4)}</td>
              <td>{formatEur(txn.price_per_gram_cents)}</td>
              <td>{formatEur(txn.gross_eur_cents)}</td>
              <td>{formatEur(txn.fee_eur_cents)}</td>
              <td>
                <span className={`badge badge--${txn.status === 'completed' ? 'success' : 'warning'}`}>
                  {txn.status}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

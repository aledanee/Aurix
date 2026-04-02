import React from 'react';
import { formatEurCents, formatGoldGrams, parseEurToCents } from '../utils/finance';

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
    return (
      <div className="card empty-state">
        <p className="empty-state__eyebrow">Transactions</p>
        <h3 className="empty-state__title">No activity yet</h3>
        <p className="empty-state__copy">
          Completed buy and sell orders will appear here as soon as your wallet starts moving.
        </p>
      </div>
    );
  }

  return (
    <div className="card table-card">
      <div className="table-card__header">
        <div>
          <p className="table-card__eyebrow">Ledger view</p>
          <h3 className="table-card__title">Transaction activity</h3>
        </div>
        <span className="badge badge--info">{transactions.length} loaded</span>
      </div>
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
                <td data-label="Date">
                  <span className="table__primary">{formatDate(txn.created_at)}</span>
                </td>
                <td data-label="Type">
                  <span className="transaction-direction">
                    <span className="transaction-direction__icon">
                      {txn.type === 'buy' ? '↑' : '↓'}
                    </span>
                    {txn.type === 'buy' ? 'Buy' : 'Sell'}
                  </span>
                </td>
                <td data-label="Grams">
                  <span className="table__primary">{formatGoldGrams(txn.gold_grams)}</span>
                </td>
                <td data-label="Price/gram">{formatEurCents(parseEurToCents(txn.price_eur_per_gram))}</td>
                <td data-label="Gross EUR">{formatEurCents(parseEurToCents(txn.gross_eur))}</td>
                <td data-label="Fee EUR">
                  {txn.fee_eur == null ? '-' : formatEurCents(parseEurToCents(txn.fee_eur))}
                </td>
                <td data-label="Status">
                  <span className={`badge badge--${txn.status === 'posted' || txn.status === 'completed' ? 'success' : 'warning'}`}>
                    {txn.status}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

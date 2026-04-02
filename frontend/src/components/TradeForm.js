import React, { useState } from 'react';
import { buyGold, sellGold } from '../api/client';

function formatEur(cents) {
  const euros = Number(cents) / 100;
  return new Intl.NumberFormat('en-EU', {
    style: 'currency',
    currency: 'EUR',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(euros);
}

export default function TradeForm({ type, goldPriceCents, onSuccess }) {
  const [grams, setGrams] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [result, setResult] = useState(null);

  const isBuy = type === 'buy';
  const estimatedCents = grams && goldPriceCents
    ? Math.round(parseFloat(grams) * Number(goldPriceCents))
    : 0;

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    setResult(null);

    const gramsNum = parseFloat(grams);
    if (!gramsNum || gramsNum <= 0) {
      setError('Please enter a valid amount of grams.');
      return;
    }

    const idempotencyKey = crypto.randomUUID();
    setLoading(true);
    try {
      const tradeFn = isBuy ? buyGold : sellGold;
      const data = await tradeFn(grams, idempotencyKey);
      setResult(data);
      setGrams('');
      if (onSuccess) onSuccess(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="card trade-form">
      <h3 className="trade-form__title">
        {isBuy ? '▲ Buy Gold' : '▼ Sell Gold'}
      </h3>

      {goldPriceCents && (
        <p className="trade-form__price">
          Current price: <strong>{formatEur(goldPriceCents)}</strong> / gram
        </p>
      )}

      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="grams">Amount (grams)</label>
          <input
            id="grams"
            type="number"
            step="0.0001"
            min="0.0001"
            className="form-input"
            placeholder="e.g. 1.5"
            value={grams}
            onChange={(e) => setGrams(e.target.value)}
            disabled={loading}
          />
        </div>

        {grams && goldPriceCents > 0 && (
          <p className="trade-form__estimate">
            Estimated {isBuy ? 'cost' : 'revenue'}:{' '}
            <strong>{formatEur(estimatedCents)}</strong>
            <span className="text-muted"> (excl. fees)</span>
          </p>
        )}

        {error && <div className="alert alert--error">{error}</div>}

        <button
          type="submit"
          className={`btn btn--block ${isBuy ? 'btn--primary' : 'btn--danger'}`}
          disabled={loading}
        >
          {loading ? 'Processing…' : isBuy ? 'Buy Gold' : 'Sell Gold'}
        </button>
      </form>

      {result && (
        <div className="alert alert--success trade-form__result">
          <strong>Trade completed!</strong>
          <ul>
            <li>Grams: {parseFloat(result.gold_grams).toFixed(4)}</li>
            <li>Total: {formatEur(result.gross_eur_cents)}</li>
            {result.fee_eur_cents != null && (
              <li>Fee: {formatEur(result.fee_eur_cents)}</li>
            )}
          </ul>
        </div>
      )}
    </div>
  );
}

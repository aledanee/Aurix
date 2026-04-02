import React, { useState } from 'react';
import { buyGold, sellGold } from '../api/client';
import {
  estimateGrossEurCents,
  formatEurCents,
  formatGoldGrams,
  isPositiveGoldAmount,
} from '../utils/finance';

export default function TradeForm({ type, goldPriceCents, onSuccess }) {
  const [grams, setGrams] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [result, setResult] = useState(null);

  const isBuy = type === 'buy';
  const estimatedCents = grams && goldPriceCents
    ? estimateGrossEurCents(grams, goldPriceCents)
    : null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    setResult(null);

    if (!isPositiveGoldAmount(grams)) {
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
      <div className="trade-form__header">
        <span className="trade-form__eyebrow">
          {isBuy ? 'Acquire gold' : 'Convert to EUR'}
        </span>
        <h3 className="trade-form__title">{isBuy ? 'Buy gold' : 'Sell gold'}</h3>
        <p className="trade-form__copy">
          {isBuy
            ? 'Submit a purchase order using the latest live quote.'
            : 'Sell part of your holdings back into EUR with the same secure flow.'}
        </p>
      </div>

      {goldPriceCents && (
        <div className="trade-form__meta">
          <p className="trade-form__price">
            <span className="trade-form__price-label">Current price</span>
            <strong>{formatEurCents(goldPriceCents)} / gram</strong>
          </p>
        </div>
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
            placeholder="e.g. 1.2500"
            value={grams}
            onChange={(e) => setGrams(e.target.value)}
            disabled={loading}
          />
          <p className="form-caption">Amounts are shown to 4 decimal places in the UI.</p>
        </div>

        {estimatedCents != null && (
          <div className="trade-form__estimate">
            <span className="trade-form__estimate-label">
              Estimated {isBuy ? 'cost' : 'revenue'}
            </span>
            <strong className="trade-form__estimate-value">
              {formatEurCents(estimatedCents)}
            </strong>
            <span className="text-muted">Before fees are applied.</span>
          </div>
        )}

        {error && <div className="alert alert--error">{error}</div>}

        <button type="submit" className="btn btn--primary btn--block" disabled={loading}>
          {loading ? 'Processing...' : isBuy ? 'Review and buy' : 'Review and sell'}
        </button>
        <p className="trade-form__helper">
          Each trade request includes an idempotency key to protect against accidental repeats.
        </p>
      </form>

      {result && (
        <div className="alert alert--success trade-form__result">
          <strong>Trade completed</strong>
          <ul>
            <li>
              <span className="trade-form__result-label">Amount</span>
              <span className="trade-form__result-value">{formatGoldGrams(result.gold_grams)}</span>
            </li>
            <li>
              <span className="trade-form__result-label">Gross total</span>
              <span className="trade-form__result-value">
                {formatEurCents(result.gross_eur_cents)}
              </span>
            </li>
            {result.fee_eur_cents != null && (
              <li>
                <span className="trade-form__result-label">Fee</span>
                <span className="trade-form__result-value">
                  {formatEurCents(result.fee_eur_cents)}
                </span>
              </li>
            )}
          </ul>
        </div>
      )}
    </div>
  );
}

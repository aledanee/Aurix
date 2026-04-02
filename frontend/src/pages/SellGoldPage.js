import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { getWallet } from '../api/client';
import useApi from '../hooks/useApi';
import TradeForm from '../components/TradeForm';
import { formatEurCents, formatGoldGrams } from '../utils/finance';

export default function SellGoldPage() {
  const wallet = useApi(getWallet);
  const navigate = useNavigate();

  useEffect(() => {
    wallet.execute();
  }, []);

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <p className="page-kicker">Trading desk</p>
          <h1 className="page-title">Sell gold</h1>
          <p className="page-subtitle">
            Convert part of your holdings back into EUR using the same live quote and controlled
            execution flow.
          </p>
        </div>

        <div className="page-chip-group">
          <div className="page-chip page-chip--accent">
            <span className="page-chip__label">Reference price</span>
            <strong className="page-chip__value">
              {formatEurCents(wallet.data?.gold_price_eur_cents)}
              <span className="page-chip__suffix">/g</span>
            </strong>
          </div>
          <div className="page-chip">
            <span className="page-chip__label">Gold available</span>
            <strong className="page-chip__value">{formatGoldGrams(wallet.data?.gold_balance_grams)}</strong>
          </div>
        </div>
      </div>

      {wallet.error && <div className="alert alert--error">{wallet.error}</div>}
      {wallet.loading && !wallet.data && <div className="spinner" />}

      <div className="trade-console">
        <div className="trade-console__main">
          <TradeForm
            type="sell"
            goldPriceCents={wallet.data?.gold_price_eur_cents}
            onSuccess={() => {
              wallet.execute();
              navigate('/transactions');
            }}
          />
        </div>

        <aside className="trade-console__side">
          <div className="card surface-card surface-card--accent">
            <div className="surface-header">
              <p className="surface-kicker">Trade context</p>
              <h2 className="surface-title">This order liquidates a portion of your gold holdings.</h2>
              <p className="surface-copy">
                Revenue is calculated from the current reference price before tenant fees are
                applied.
              </p>
            </div>

            <div className="detail-list">
              <div className="detail-list__row">
                <span className="detail-list__label">Gold available</span>
                <span className="detail-list__value">{formatGoldGrams(wallet.data?.gold_balance_grams)}</span>
              </div>
              <div className="detail-list__row">
                <span className="detail-list__label">EUR after settlement</span>
                <span className="detail-list__value">
                  Returned directly to your wallet balance.
                </span>
              </div>
            </div>
          </div>

          <div className="card surface-card">
            <div className="surface-header">
              <p className="surface-kicker">What happens next</p>
              <h2 className="surface-title">Controlled exit flow</h2>
            </div>
            <ol className="process-list">
              <li>Enter the grams you want to convert back into EUR.</li>
              <li>Aurix applies the current quote and the configured sell fee.</li>
              <li>The completed sale appears in Transactions with gross and fee totals.</li>
            </ol>
          </div>
        </aside>
      </div>
    </div>
  );
}

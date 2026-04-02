import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { getWallet } from '../api/client';
import useApi from '../hooks/useApi';
import TradeForm from '../components/TradeForm';
import { formatEurCents, formatGoldGrams } from '../utils/finance';

export default function BuyGoldPage() {
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
          <h1 className="page-title">Buy gold</h1>
          <p className="page-subtitle">
            Enter a gram amount, review the latest quote, and commit cash from your wallet in
            one controlled flow.
          </p>
        </div>

        <div className="page-chip-group">
          <div className="page-chip page-chip--accent">
            <span className="page-chip__label">Reference price</span>
            <strong className="page-chip__value">
              {formatEurCents(wallet.data?.gold_price_cents)}
              <span className="page-chip__suffix">/g</span>
            </strong>
          </div>
          <div className="page-chip">
            <span className="page-chip__label">EUR available</span>
            <strong className="page-chip__value">
              {formatEurCents(wallet.data?.eur_balance_cents)}
            </strong>
          </div>
        </div>
      </div>

      {wallet.error && <div className="alert alert--error">{wallet.error}</div>}
      {wallet.loading && !wallet.data && <div className="spinner" />}

      <div className="trade-console">
        <div className="trade-console__main">
          <TradeForm
            type="buy"
            goldPriceCents={wallet.data?.gold_price_cents}
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
              <h2 className="surface-title">This order draws from your available EUR balance.</h2>
              <p className="surface-copy">
                The estimate uses the current reference price returned by the wallet endpoint.
              </p>
            </div>

            <div className="detail-list">
              <div className="detail-list__row">
                <span className="detail-list__label">Cash available</span>
                <span className="detail-list__value">
                  {formatEurCents(wallet.data?.eur_balance_cents)}
                </span>
              </div>
              <div className="detail-list__row">
                <span className="detail-list__label">Gold currently held</span>
                <span className="detail-list__value">{formatGoldGrams(wallet.data?.gold_grams)}</span>
              </div>
            </div>
          </div>

          <div className="card surface-card">
            <div className="surface-header">
              <p className="surface-kicker">What happens next</p>
              <h2 className="surface-title">From quote to recorded trade</h2>
            </div>
            <ol className="process-list">
              <li>Enter the gram amount you want to acquire.</li>
              <li>Aurix applies the live quote and tenant fee rules before settlement.</li>
              <li>The completed purchase is posted to your transaction history.</li>
            </ol>
          </div>
        </aside>
      </div>
    </div>
  );
}

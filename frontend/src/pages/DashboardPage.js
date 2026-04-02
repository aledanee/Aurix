import React, { useEffect } from 'react';
import { Link } from 'react-router-dom';
import { getWallet, getTransactions } from '../api/client';
import useApi from '../hooks/useApi';
import WalletCard from '../components/WalletCard';
import TransactionList from '../components/TransactionList';
import { formatEurCents, formatGoldGrams } from '../utils/finance';

export default function DashboardPage() {
  const wallet = useApi(getWallet);
  const txns = useApi(getTransactions);
  const recentCount = txns.data?.transactions?.length || 0;

  useEffect(() => {
    wallet.execute();
    txns.execute(null, 5);
  }, []);

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <p className="page-kicker">Overview</p>
          <h1 className="page-title">Dashboard</h1>
          <p className="page-subtitle">
            Track balances, current pricing, and your latest account activity from one view.
          </p>
        </div>

        <div className="page-chip-group">
          {wallet.data?.gold_price_cents != null && (
            <div className="page-chip page-chip--accent">
              <span className="page-chip__label">Live gold price</span>
              <strong className="page-chip__value">
                {formatEurCents(wallet.data.gold_price_cents)}
                <span className="page-chip__suffix">/g</span>
              </strong>
            </div>
          )}
          <div className="page-chip">
            <span className="page-chip__label">Recent entries</span>
            <strong className="page-chip__value">{recentCount}</strong>
          </div>
        </div>
      </div>

      {wallet.error && <div className="alert alert--error">{wallet.error}</div>}
      {wallet.loading && <div className="spinner" />}

      <div className="dashboard-layout">
        <div className="dashboard-layout__main">
          <WalletCard wallet={wallet.data} />
        </div>

        <div className="card surface-card dashboard-panel">
          <div className="surface-header">
            <p className="surface-kicker">Quick actions</p>
            <h2 className="surface-title">Move from quote to execution without leaving the workspace.</h2>
            <p className="surface-copy">
              Aurix keeps balances, pricing context, and post-trade review inside a single
              product shell.
            </p>
          </div>

          <div className="quick-link-grid">
            <Link className="quick-link" to="/buy">
              <span className="quick-link__eyebrow">Trade</span>
              <strong className="quick-link__title">Buy gold</strong>
              <span className="quick-link__copy">Use your available EUR balance to place a new order.</span>
            </Link>
            <Link className="quick-link" to="/sell">
              <span className="quick-link__eyebrow">Trade</span>
              <strong className="quick-link__title">Sell gold</strong>
              <span className="quick-link__copy">Convert holdings back into EUR with the current quote.</span>
            </Link>
          </div>

          <div className="detail-list">
            <div className="detail-list__row">
              <span className="detail-list__label">Gold on hand</span>
              <span className="detail-list__value">{formatGoldGrams(wallet.data?.gold_grams)}</span>
            </div>
            <div className="detail-list__row">
              <span className="detail-list__label">EUR available</span>
              <span className="detail-list__value">
                {formatEurCents(wallet.data?.eur_balance_cents)}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div className="section">
        <div className="section-header">
          <div>
            <h2 className="section-title">Recent transactions</h2>
            <p className="section-copy">Your latest trades, fees, and balance movements.</p>
          </div>
          <Link className="btn btn--secondary btn--sm" to="/transactions">
            View all
          </Link>
        </div>
        {txns.error && <div className="alert alert--error">{txns.error}</div>}
        {txns.loading && <div className="spinner" />}
        <TransactionList transactions={txns.data?.transactions} />
      </div>
    </div>
  );
}

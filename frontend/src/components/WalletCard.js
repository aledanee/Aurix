import React from 'react';
import { formatEurCents, formatGoldGrams } from '../utils/finance';

export default function WalletCard({ wallet }) {
  if (!wallet) return null;

  return (
    <div className="wallet-cards">
      <div className="card wallet-card wallet-card--gold">
        <div className="wallet-card__inner">
          <div className="wallet-card__top">
            <div>
              <div className="wallet-card__eyebrow">Portfolio</div>
              <div className="wallet-card__label">Gold balance</div>
            </div>
            <span className="wallet-card__tag">Asset</span>
          </div>
          <div className="wallet-card__value-row">
            <div className="wallet-card__value">{formatGoldGrams(wallet.gold_grams)}</div>
            <div className="wallet-card__icon">Au</div>
          </div>
          <div className="wallet-card__foot">
            <p className="wallet-card__caption">Available for buy and sell orders.</p>
            <span className="wallet-card__status">Live</span>
          </div>
        </div>
      </div>
      <div className="card wallet-card wallet-card--eur">
        <div className="wallet-card__inner">
          <div className="wallet-card__top">
            <div>
              <div className="wallet-card__eyebrow">Liquidity</div>
              <div className="wallet-card__label">EUR balance</div>
            </div>
            <span className="wallet-card__tag">Cash</span>
          </div>
          <div className="wallet-card__value-row">
            <div className="wallet-card__value">{formatEurCents(wallet.eur_balance_cents)}</div>
            <div className="wallet-card__icon">EUR</div>
          </div>
          <div className="wallet-card__foot">
            <p className="wallet-card__caption">Ready for trading, fees, and settlement activity.</p>
            <span className="wallet-card__status">Ready</span>
          </div>
        </div>
      </div>
    </div>
  );
}

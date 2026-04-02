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

function formatGold(grams) {
  return parseFloat(grams).toFixed(8) + ' g';
}

export default function WalletCard({ wallet }) {
  if (!wallet) return null;

  return (
    <div className="wallet-cards">
      <div className="card wallet-card wallet-card--gold">
        <div className="wallet-card__label">Gold Balance</div>
        <div className="wallet-card__value">{formatGold(wallet.gold_grams)}</div>
        <div className="wallet-card__icon">✦</div>
      </div>
      <div className="card wallet-card wallet-card--eur">
        <div className="wallet-card__label">EUR Balance</div>
        <div className="wallet-card__value">{formatEur(wallet.eur_balance_cents)}</div>
        <div className="wallet-card__icon">€</div>
      </div>
    </div>
  );
}

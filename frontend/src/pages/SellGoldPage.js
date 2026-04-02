import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { getWallet } from '../api/client';
import useApi from '../hooks/useApi';
import TradeForm from '../components/TradeForm';

export default function SellGoldPage() {
  const wallet = useApi(getWallet);
  const navigate = useNavigate();

  useEffect(() => {
    wallet.execute();
  }, []);

  return (
    <div className="page">
      <h1 className="page-title">Sell Gold</h1>
      {wallet.error && <div className="alert alert--error">{wallet.error}</div>}
      <TradeForm
        type="sell"
        goldPriceCents={wallet.data?.gold_price_cents}
        onSuccess={() => {
          wallet.execute();
          navigate('/transactions');
        }}
      />
    </div>
  );
}

import React, { useEffect } from 'react';
import { getWallet, getTransactions } from '../api/client';
import useApi from '../hooks/useApi';
import WalletCard from '../components/WalletCard';
import TransactionList from '../components/TransactionList';

export default function DashboardPage() {
  const wallet = useApi(getWallet);
  const txns = useApi(getTransactions);

  useEffect(() => {
    wallet.execute();
    txns.execute(null, 5);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="page">
      <h1 className="page-title">Dashboard</h1>

      {wallet.error && <div className="alert alert--error">{wallet.error}</div>}
      {wallet.loading && <div className="spinner" />}
      <WalletCard wallet={wallet.data} />

      <div className="section">
        <h2 className="section-title">Recent Transactions</h2>
        {txns.error && <div className="alert alert--error">{txns.error}</div>}
        {txns.loading && <div className="spinner" />}
        <TransactionList transactions={txns.data?.transactions} />
      </div>
    </div>
  );
}

import React, { useEffect, useState } from 'react';
import {
  adminListTenants,
  adminDeactivateTenant,
  adminUpdateGoldPrice,
  adminUpdateFeeConfig,
  adminTriggerEtl,
} from '../api/client';

function formatEur(cents) {
  const euros = Number(cents) / 100;
  return new Intl.NumberFormat('en-EU', {
    style: 'currency',
    currency: 'EUR',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(euros);
}

export default function AdminPage() {
  // ─── Tenants ──────────────────────────────────────────────────
  const [tenants, setTenants] = useState([]);
  const [tenantsLoading, setTenantsLoading] = useState(false);
  const [tenantsError, setTenantsError] = useState(null);

  const loadTenants = async () => {
    setTenantsLoading(true);
    setTenantsError(null);
    try {
      const data = await adminListTenants();
      setTenants(data.tenants || []);
    } catch (err) {
      setTenantsError(err.message);
    } finally {
      setTenantsLoading(false);
    }
  };

  useEffect(() => {
    loadTenants();
  }, []);

  const handleDeactivate = async (tenantId) => {
    if (!window.confirm('Deactivate this tenant?')) return;
    try {
      await adminDeactivateTenant(tenantId);
      loadTenants();
    } catch (err) {
      setTenantsError(err.message);
    }
  };

  // ─── Gold Price ───────────────────────────────────────────────
  const [priceEur, setPriceEur] = useState('');
  const [priceLoading, setPriceLoading] = useState(false);
  const [priceError, setPriceError] = useState(null);
  const [priceSuccess, setPriceSuccess] = useState(null);

  const handleUpdatePrice = async (e) => {
    e.preventDefault();
    setPriceError(null);
    setPriceSuccess(null);
    setPriceLoading(true);
    try {
      await adminUpdateGoldPrice(priceEur);
      setPriceSuccess('Gold price updated.');
      setPriceEur('');
    } catch (err) {
      setPriceError(err.message);
    } finally {
      setPriceLoading(false);
    }
  };

  // ─── Fee Config ───────────────────────────────────────────────
  const [feeTenantId, setFeeTenantId] = useState('');
  const [buyFeeRate, setBuyFeeRate] = useState('');
  const [sellFeeRate, setSellFeeRate] = useState('');
  const [minFeeCents, setMinFeeCents] = useState('');
  const [feeLoading, setFeeLoading] = useState(false);
  const [feeError, setFeeError] = useState(null);
  const [feeSuccess, setFeeSuccess] = useState(null);

  const handleUpdateFees = async (e) => {
    e.preventDefault();
    setFeeError(null);
    setFeeSuccess(null);
    setFeeLoading(true);
    try {
      await adminUpdateFeeConfig(
        feeTenantId,
        buyFeeRate,
        sellFeeRate,
        parseInt(minFeeCents, 10)
      );
      setFeeSuccess('Fee config updated.');
    } catch (err) {
      setFeeError(err.message);
    } finally {
      setFeeLoading(false);
    }
  };

  // ─── ETL ──────────────────────────────────────────────────────
  const [etlLoading, setEtlLoading] = useState(false);
  const [etlError, setEtlError] = useState(null);
  const [etlSuccess, setEtlSuccess] = useState(null);

  const handleTriggerEtl = async () => {
    setEtlError(null);
    setEtlSuccess(null);
    setEtlLoading(true);
    try {
      await adminTriggerEtl();
      setEtlSuccess('ETL triggered successfully.');
    } catch (err) {
      setEtlError(err.message);
    } finally {
      setEtlLoading(false);
    }
  };

  return (
    <div className="page">
      <h1 className="page-title">Admin Panel</h1>

      {/* Tenants Table */}
      <div className="card admin-section">
        <h2>Tenants</h2>
        {tenantsError && <div className="alert alert--error">{tenantsError}</div>}
        {tenantsLoading && <div className="spinner" />}
        <div className="table-responsive">
          <table className="table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Code</th>
                <th>Name</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {tenants.map((t) => (
                <tr key={t.id}>
                  <td className="text-muted">{t.id}</td>
                  <td>{t.code}</td>
                  <td>{t.name}</td>
                  <td>
                    <span
                      className={`badge ${
                        t.status === 'active' ? 'badge--success' : 'badge--danger'
                      }`}
                    >
                      {t.status}
                    </span>
                  </td>
                  <td>
                    {t.status === 'active' && (
                      <button
                        className="btn btn--danger btn--sm"
                        onClick={() => handleDeactivate(t.id)}
                      >
                        Deactivate
                      </button>
                    )}
                  </td>
                </tr>
              ))}
              {tenants.length === 0 && !tenantsLoading && (
                <tr>
                  <td colSpan="5" className="text-muted text-center">
                    No tenants found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Gold Price */}
      <div className="card admin-section">
        <h2>Update Gold Price</h2>
        <form onSubmit={handleUpdatePrice} className="inline-form">
          <div className="form-group">
            <label htmlFor="priceEur">Price (EUR per gram)</label>
            <input
              id="priceEur"
              type="text"
              className="form-input"
              value={priceEur}
              onChange={(e) => setPriceEur(e.target.value)}
              placeholder="e.g. 85.50"
              required
              disabled={priceLoading}
            />
          </div>
          {priceError && <div className="alert alert--error">{priceError}</div>}
          {priceSuccess && <div className="alert alert--success">{priceSuccess}</div>}
          <button type="submit" className="btn btn--primary" disabled={priceLoading}>
            {priceLoading ? 'Updating…' : 'Update Price'}
          </button>
        </form>
      </div>

      {/* Fee Config */}
      <div className="card admin-section">
        <h2>Fee Configuration</h2>
        <form onSubmit={handleUpdateFees}>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="feeTenantId">Tenant ID</label>
              <select
                id="feeTenantId"
                className="form-input"
                value={feeTenantId}
                onChange={(e) => setFeeTenantId(e.target.value)}
                required
                disabled={feeLoading}
              >
                <option value="">Select tenant</option>
                {tenants.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.code} — {t.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label htmlFor="buyFeeRate">Buy Fee Rate</label>
              <input
                id="buyFeeRate"
                type="text"
                className="form-input"
                value={buyFeeRate}
                onChange={(e) => setBuyFeeRate(e.target.value)}
                placeholder="e.g. 0.015"
                required
                disabled={feeLoading}
              />
            </div>
            <div className="form-group">
              <label htmlFor="sellFeeRate">Sell Fee Rate</label>
              <input
                id="sellFeeRate"
                type="text"
                className="form-input"
                value={sellFeeRate}
                onChange={(e) => setSellFeeRate(e.target.value)}
                placeholder="e.g. 0.015"
                required
                disabled={feeLoading}
              />
            </div>
            <div className="form-group">
              <label htmlFor="minFeeCents">Min Fee (EUR cents)</label>
              <input
                id="minFeeCents"
                type="number"
                className="form-input"
                value={minFeeCents}
                onChange={(e) => setMinFeeCents(e.target.value)}
                placeholder="e.g. 50"
                required
                disabled={feeLoading}
              />
            </div>
          </div>
          {feeError && <div className="alert alert--error">{feeError}</div>}
          {feeSuccess && <div className="alert alert--success">{feeSuccess}</div>}
          <button type="submit" className="btn btn--primary" disabled={feeLoading}>
            {feeLoading ? 'Updating…' : 'Update Fees'}
          </button>
        </form>
      </div>

      {/* ETL Trigger */}
      <div className="card admin-section">
        <h2>ETL Pipeline</h2>
        <p className="text-muted">
          Manually trigger the ETL pipeline to refresh insight data.
        </p>
        {etlError && <div className="alert alert--error">{etlError}</div>}
        {etlSuccess && <div className="alert alert--success">{etlSuccess}</div>}
        <button
          className="btn btn--primary"
          onClick={handleTriggerEtl}
          disabled={etlLoading}
        >
          {etlLoading ? 'Running…' : 'Trigger ETL'}
        </button>
      </div>
    </div>
  );
}

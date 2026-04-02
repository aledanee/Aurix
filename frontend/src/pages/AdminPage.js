import React, { useEffect, useState } from 'react';
import {
  adminListTenants,
  adminDeactivateTenant,
  adminUpdateGoldPrice,
  adminUpdateFeeConfig,
  adminTriggerEtl,
} from '../api/client';
import { formatEurCents } from '../utils/finance';

export default function AdminPage() {
  const [tenants, setTenants] = useState([]);
  const [tenantsLoading, setTenantsLoading] = useState(false);
  const [tenantsError, setTenantsError] = useState(null);
  const tenantCount = tenants.length;

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
      <div className="page-header">
        <div>
          <p className="page-kicker">Operations</p>
          <h1 className="page-title">Admin</h1>
          <p className="page-subtitle">
            Manage tenants, pricing inputs, fee rules, and manual ETL operations from one
            structured control surface.
          </p>
        </div>

        <div className="page-chip-group">
          <div className="page-chip page-chip--accent">
            <span className="page-chip__label">Tenants</span>
            <strong className="page-chip__value">{tenantCount}</strong>
          </div>
          <div className="page-chip">
            <span className="page-chip__label">Min fee preview</span>
            <strong className="page-chip__value">
              {minFeeCents ? formatEurCents(minFeeCents) : 'Not set'}
            </strong>
          </div>
        </div>
      </div>

      <div className="card surface-card admin-section">
        <div className="surface-header surface-header--split">
          <div>
            <p className="surface-kicker">Tenant management</p>
            <h2 className="surface-title">Tenants</h2>
            <p className="surface-copy">
              Review active organizations, inspect status, and deactivate access when needed.
            </p>
          </div>
          <span className="badge badge--info">
            {tenantsLoading ? 'Syncing' : `${tenantCount} loaded`}
          </span>
        </div>
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
                  <td data-label="ID" className="text-muted">{t.id}</td>
                  <td data-label="Code">{t.code}</td>
                  <td data-label="Name">{t.name}</td>
                  <td data-label="Status">
                    <span
                      className={`badge ${
                        t.status === 'active' ? 'badge--success' : 'badge--danger'
                      }`}
                    >
                      {t.status}
                    </span>
                  </td>
                  <td data-label="Actions">
                    {t.status === 'active' && (
                      <button
                        type="button"
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

      <div className="admin-grid">
        <div className="card surface-card admin-section">
          <div className="surface-header">
            <p className="surface-kicker">Fee rules</p>
            <h2 className="surface-title">Fee configuration</h2>
            <p className="surface-copy">
              Assign buy and sell fee rates per tenant and define the minimum fee threshold.
            </p>
          </div>
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
                      {t.code} - {t.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label htmlFor="buyFeeRate">Buy fee rate</label>
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
                <label htmlFor="sellFeeRate">Sell fee rate</label>
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
                <label htmlFor="minFeeCents">Min fee (EUR cents)</label>
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
                {minFeeCents && (
                  <p className="form-caption">Preview: {formatEurCents(minFeeCents)}</p>
                )}
              </div>
            </div>
            {feeError && <div className="alert alert--error">{feeError}</div>}
            {feeSuccess && <div className="alert alert--success">{feeSuccess}</div>}
            <button type="submit" className="btn btn--primary" disabled={feeLoading}>
              {feeLoading ? 'Updating...' : 'Update fees'}
            </button>
          </form>
        </div>

        <div className="admin-side-stack">
          <div className="card surface-card admin-section">
            <div className="surface-header">
              <p className="surface-kicker">Pricing</p>
              <h2 className="surface-title">Update gold price</h2>
              <p className="surface-copy">
                Provide the new EUR per gram reference value used by the trading flow.
              </p>
            </div>
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
                <p className="form-caption">Use the plain EUR amount per gram.</p>
              </div>
              {priceError && <div className="alert alert--error">{priceError}</div>}
              {priceSuccess && <div className="alert alert--success">{priceSuccess}</div>}
              <button type="submit" className="btn btn--primary" disabled={priceLoading}>
                {priceLoading ? 'Updating...' : 'Update price'}
              </button>
            </form>
          </div>

          <div className="card surface-card admin-section">
            <div className="surface-header">
              <p className="surface-kicker">Pipeline</p>
              <h2 className="surface-title">ETL pipeline</h2>
              <p className="surface-copy">
                Manually trigger the ETL job to refresh downstream insight generation.
              </p>
            </div>
            {etlError && <div className="alert alert--error">{etlError}</div>}
            {etlSuccess && <div className="alert alert--success">{etlSuccess}</div>}
            <button
              type="button"
              className="btn btn--primary"
              onClick={handleTriggerEtl}
              disabled={etlLoading}
            >
              {etlLoading ? 'Running...' : 'Trigger ETL'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

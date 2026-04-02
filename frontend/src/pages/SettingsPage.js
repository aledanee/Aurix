import React, { useState } from 'react';
import { changePassword, getPrivacyExport, requestErasure } from '../api/client';

export default function SettingsPage() {
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmNew, setConfirmNew] = useState('');
  const [pwLoading, setPwLoading] = useState(false);
  const [pwError, setPwError] = useState(null);
  const [pwSuccess, setPwSuccess] = useState(null);

  const handleChangePassword = async (e) => {
    e.preventDefault();
    setPwError(null);
    setPwSuccess(null);

    if (newPassword !== confirmNew) {
      setPwError('New passwords do not match.');
      return;
    }
    if (newPassword.length < 8) {
      setPwError('Password must be at least 8 characters.');
      return;
    }

    setPwLoading(true);
    try {
      await changePassword(currentPassword, newPassword);
      setPwSuccess('Password changed successfully.');
      setCurrentPassword('');
      setNewPassword('');
      setConfirmNew('');
    } catch (err) {
      setPwError(err.message);
    } finally {
      setPwLoading(false);
    }
  };

  const [exportLoading, setExportLoading] = useState(false);
  const [exportError, setExportError] = useState(null);
  const [exportSuccess, setExportSuccess] = useState(null);

  const handleExport = async () => {
    setExportError(null);
    setExportSuccess(null);
    setExportLoading(true);
    try {
      const data = await getPrivacyExport();
      const blob = new Blob([JSON.stringify(data, null, 2)], {
        type: 'application/json',
      });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'aurix-data-export.json';
      a.click();
      URL.revokeObjectURL(url);
      setExportSuccess('Data exported successfully.');
    } catch (err) {
      setExportError(err.message);
    } finally {
      setExportLoading(false);
    }
  };

  const [erasureLoading, setErasureLoading] = useState(false);
  const [erasureError, setErasureError] = useState(null);
  const [erasureSuccess, setErasureSuccess] = useState(null);

  const handleErasure = async () => {
    if (
      !window.confirm(
        'Are you sure you want to request account erasure? This action cannot be undone.'
      )
    ) {
      return;
    }
    setErasureError(null);
    setErasureSuccess(null);
    setErasureLoading(true);
    try {
      await requestErasure();
      setErasureSuccess('Erasure request submitted.');
    } catch (err) {
      setErasureError(err.message);
    } finally {
      setErasureLoading(false);
    }
  };

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <p className="page-kicker">Account</p>
          <h1 className="page-title">Settings</h1>
          <p className="page-subtitle">
            Manage password changes, export requests, and account-level privacy actions from one
            organized control surface.
          </p>
        </div>

        <div className="page-chip-group">
          <div className="page-chip page-chip--accent">
            <span className="page-chip__label">Security</span>
            <strong className="page-chip__value">Password</strong>
          </div>
          <div className="page-chip">
            <span className="page-chip__label">Privacy</span>
            <strong className="page-chip__value">Export + erasure</strong>
          </div>
        </div>
      </div>

      <div className="settings-grid">
        <div className="card surface-card settings-section">
          <div className="surface-header">
            <p className="surface-kicker">Security</p>
            <h2 className="surface-title">Change password</h2>
            <p className="surface-copy">
              Update the credential used to access your Aurix workspace.
            </p>
          </div>

          <form onSubmit={handleChangePassword}>
            <div className="form-group">
              <label htmlFor="currentPassword">Current password</label>
              <input
                id="currentPassword"
                type="password"
                className="form-input"
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                required
                disabled={pwLoading}
              />
            </div>
            <div className="form-group">
              <label htmlFor="newPassword">New password</label>
              <input
                id="newPassword"
                type="password"
                className="form-input"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                required
                disabled={pwLoading}
              />
            </div>
            <div className="form-group">
              <label htmlFor="confirmNew">Confirm new password</label>
              <input
                id="confirmNew"
                type="password"
                className="form-input"
                value={confirmNew}
                onChange={(e) => setConfirmNew(e.target.value)}
                required
                disabled={pwLoading}
              />
            </div>
            {pwError && <div className="alert alert--error">{pwError}</div>}
            {pwSuccess && <div className="alert alert--success">{pwSuccess}</div>}
            <button type="submit" className="btn btn--primary" disabled={pwLoading}>
              {pwLoading ? 'Changing...' : 'Change password'}
            </button>
          </form>
        </div>

        <div className="settings-side">
          <div className="card surface-card settings-section">
            <div className="surface-header">
              <p className="surface-kicker">Privacy</p>
              <h2 className="surface-title">Data controls</h2>
              <p className="surface-copy">
                Export your account data or submit a permanent erasure request.
              </p>
            </div>

            <div className="action-grid">
              <div className="action-tile">
                <div className="action-tile__header">
                  <h3 className="action-tile__title">Export data</h3>
                  <span className="badge badge--info">JSON</span>
                </div>
                <p>Download a copy of all data currently associated with your account.</p>
                {exportError && <div className="alert alert--error">{exportError}</div>}
                {exportSuccess && <div className="alert alert--success">{exportSuccess}</div>}
                <button
                  type="button"
                  className="btn btn--secondary"
                  onClick={handleExport}
                  disabled={exportLoading}
                >
                  {exportLoading ? 'Exporting...' : 'Export data'}
                </button>
              </div>

              <div className="action-tile action-tile--danger">
                <div className="action-tile__header">
                  <h3 className="action-tile__title">Request erasure</h3>
                  <span className="badge badge--danger">Permanent</span>
                </div>
                <p>Submit a permanent deletion request for your account and associated data.</p>
                {erasureError && <div className="alert alert--error">{erasureError}</div>}
                {erasureSuccess && <div className="alert alert--success">{erasureSuccess}</div>}
                <button
                  type="button"
                  className="btn btn--danger"
                  onClick={handleErasure}
                  disabled={erasureLoading}
                >
                  {erasureLoading ? 'Requesting...' : 'Request erasure'}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

import React, { useState } from 'react';
import { changePassword, getPrivacyExport, requestErasure } from '../api/client';

export default function SettingsPage() {
  // ─── Change Password ─────────────────────────────────────────
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

  // ─── Privacy Export ───────────────────────────────────────────
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

  // ─── Erasure Request ──────────────────────────────────────────
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
      <h1 className="page-title">Settings</h1>

      {/* Change Password */}
      <div className="card settings-section">
        <h2>Change Password</h2>
        <form onSubmit={handleChangePassword}>
          <div className="form-group">
            <label htmlFor="currentPassword">Current Password</label>
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
            <label htmlFor="newPassword">New Password</label>
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
            <label htmlFor="confirmNew">Confirm New Password</label>
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
            {pwLoading ? 'Changing…' : 'Change Password'}
          </button>
        </form>
      </div>

      {/* Privacy */}
      <div className="card settings-section">
        <h2>Privacy &amp; Data</h2>
        <div className="settings-actions">
          <div>
            <p>Download a copy of all your data.</p>
            {exportError && <div className="alert alert--error">{exportError}</div>}
            {exportSuccess && <div className="alert alert--success">{exportSuccess}</div>}
            <button
              className="btn btn--secondary"
              onClick={handleExport}
              disabled={exportLoading}
            >
              {exportLoading ? 'Exporting…' : 'Export Data'}
            </button>
          </div>
          <div>
            <p>Request permanent deletion of your account and data.</p>
            {erasureError && <div className="alert alert--error">{erasureError}</div>}
            {erasureSuccess && <div className="alert alert--success">{erasureSuccess}</div>}
            <button
              className="btn btn--danger"
              onClick={handleErasure}
              disabled={erasureLoading}
            >
              {erasureLoading ? 'Requesting…' : 'Request Erasure'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

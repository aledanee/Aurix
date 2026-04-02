import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import useAuth from '../hooks/useAuth';

export default function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const [tenantOptions, setTenantOptions] = useState(null);
  const tenantCount = tenantOptions?.length || 0;

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    setTenantOptions(null);
    setLoading(true);
    try {
      await login(email, password);
      navigate('/');
    } catch (err) {
      if (err.code === 'tenant_selection_required' && err.status === 409) {
        // Parse tenants from error response
        setTenantOptions(err.tenants || []);
      } else {
        setError(err.message);
      }
    } finally {
      setLoading(false);
    }
  };

  const handleTenantSelect = async (tenantCode) => {
    setError(null);
    setLoading(true);
    try {
      await login(email, password, tenantCode);
      navigate('/');
    } catch (err) {
      setError(err.message);
      setTenantOptions(null);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-shell">
        <section className="auth-panel auth-panel--aside">
          <div className="auth-brand">
            <span className="brand-mark">A</span>
            <div className="brand-lockup">
              <span className="brand-text">Aurix</span>
              <span className="brand-subtitle">Multi-tenant gold trading</span>
            </div>
          </div>

          <div className="auth-copy">
            <span className="auth-badge">
              {tenantOptions ? 'Tenant selection' : 'Secure sign in'}
            </span>
            <h1 className="auth-title">
              Trade and monitor digital gold from a cleaner, calmer workspace.
            </h1>
            <p className="auth-description">
              Access wallet balances, trading tools, transaction history, and AI insights
              without leaving the product flow.
            </p>
          </div>

          <div className="auth-points">
            <div className="auth-point">
              <span className="auth-point__title">Tenant-aware access</span>
              <p className="auth-point__copy">
                The sign-in flow keeps your organization context attached to the account.
              </p>
            </div>
            <div className="auth-point">
              <span className="auth-point__title">Focused trading workspace</span>
              <p className="auth-point__copy">
                Check balances, place orders, and review recent activity from one shell.
              </p>
            </div>
            <div className="auth-point">
              <span className="auth-point__title">Protected sessions</span>
              <p className="auth-point__copy">
                Access tokens stay short-lived and the app handles refresh behind the scenes.
              </p>
            </div>
          </div>

          <div className="auth-metric">
            <span className="auth-metric__label">
              {tenantOptions ? 'Organizations found' : 'Session posture'}
            </span>
            <strong className="auth-metric__value">
              {tenantOptions ? tenantCount : 'Protected'}
            </strong>
            <p className="auth-metric__copy">
              {tenantOptions
                ? 'Choose the workspace you want to enter with this email.'
                : 'Use your account credentials to continue into the Aurix workspace.'}
            </p>
          </div>
        </section>

        <section className="auth-panel auth-panel--main">
          <div className="auth-form-shell">
            <div className="auth-form-header">
              <p className="auth-form-kicker">
                {tenantOptions ? 'Choose a workspace' : 'Welcome back'}
              </p>
              <h2 className="auth-form-title">
                {tenantOptions ? 'Select your tenant' : 'Sign in to Aurix'}
              </h2>
              <p className="auth-form-subtitle">
                {tenantOptions
                  ? 'We found multiple organizations associated with this email.'
                  : 'Use your email and password to continue.'}
              </p>
            </div>

            {error && <div className="alert alert--error">{error}</div>}

            {tenantOptions ? (
              <div className="tenant-picker">
                <p className="tenant-picker__copy">
                  Your email belongs to more than one organization. Pick the tenant code you
                  want to use for this session.
                </p>
                <div className="tenant-list">
                  {tenantOptions.map((tenant) => (
                    <button
                      key={tenant.tenant_code}
                      type="button"
                      className="tenant-option"
                      onClick={() => handleTenantSelect(tenant.tenant_code)}
                      disabled={loading}
                    >
                      <span className="tenant-option__label">Tenant code</span>
                      <span className="tenant-option__value">{tenant.tenant_code}</span>
                      <span className="tenant-option__action">Continue</span>
                    </button>
                  ))}
                </div>
                <button
                  type="button"
                  className="btn btn--text btn--block"
                  onClick={() => setTenantOptions(null)}
                  disabled={loading}
                >
                  Back to sign in
                </button>
              </div>
            ) : (
              <form className="auth-form" onSubmit={handleSubmit}>
                <div className="form-group">
                  <label htmlFor="email">Email</label>
                  <input
                    id="email"
                    type="email"
                    className="form-input"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                    autoComplete="email"
                    required
                    disabled={loading}
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="password">Password</label>
                  <input
                    id="password"
                    type="password"
                    className="form-input"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Enter your password"
                    autoComplete="current-password"
                    required
                    disabled={loading}
                  />
                </div>

                <button type="submit" className="btn btn--primary btn--block" disabled={loading}>
                  {loading ? 'Signing in...' : 'Sign in'}
                </button>
              </form>
            )}

            <p className="auth-footer">
              Do not have an account yet? <Link to="/register">Create one</Link>
            </p>
          </div>
        </section>
      </div>
    </div>
  );
}

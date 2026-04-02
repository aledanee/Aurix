import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import useAuth from '../hooks/useAuth';

export default function RegisterPage() {
  const { register } = useAuth();
  const navigate = useNavigate();

  const [tenantCode, setTenantCode] = useState('aurix-demo');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);

    if (password !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }

    if (password.length < 8) {
      setError('Password must be at least 8 characters.');
      return;
    }

    setLoading(true);
    try {
      await register(tenantCode, email, password);
      navigate('/');
    } catch (err) {
      setError(err.message);
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
              <span className="brand-subtitle">Account onboarding</span>
            </div>
          </div>

          <div className="auth-copy">
            <span className="auth-badge">Create secure access</span>
            <h1 className="auth-title">
              Set up your Aurix account with the tenant code supplied by your organization.
            </h1>
            <p className="auth-description">
              Registration keeps the same multi-tenant flow as login, so each account lands in
              the correct workspace from the start.
            </p>
          </div>

          <div className="auth-points">
            <div className="auth-point">
              <span className="auth-point__title">Tenant code required</span>
              <p className="auth-point__copy">
                Use the exact tenant code shared with you to register under the right company.
              </p>
            </div>
            <div className="auth-point">
              <span className="auth-point__title">Fast wallet onboarding</span>
              <p className="auth-point__copy">
                Start with the same wallet, transactions, and insight flows used after login.
              </p>
            </div>
            <div className="auth-point">
              <span className="auth-point__title">Secure credentials</span>
              <p className="auth-point__copy">
                Choose a strong password now and manage updates later from settings.
              </p>
            </div>
          </div>

          <div className="auth-metric">
            <span className="auth-metric__label">Required field</span>
            <strong className="auth-metric__value">tenant_code</strong>
            <p className="auth-metric__copy">
              Registration will not complete until the tenant code is provided.
            </p>
          </div>
        </section>

        <section className="auth-panel auth-panel--main">
          <div className="auth-form-shell">
            <div className="auth-form-header">
              <p className="auth-form-kicker">Open your account</p>
              <h2 className="auth-form-title">Create your Aurix login</h2>
              <p className="auth-form-subtitle">
                Enter your organization tenant code, work email, and a password with at least
                eight characters.
              </p>
            </div>

            <form className="auth-form" onSubmit={handleSubmit}>
              <div className="form-group">
                <label htmlFor="tenantCode">Tenant code</label>
                <input
                  id="tenantCode"
                  type="text"
                  className="form-input"
                  value={tenantCode}
                  onChange={(e) => setTenantCode(e.target.value)}
                  placeholder="aurix-demo"
                  autoComplete="off"
                  spellCheck="false"
                  required
                  disabled={loading}
                />
                <p className="form-caption">Required. Use the code assigned by your organization.</p>
              </div>

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
                  placeholder="Minimum 8 characters"
                  autoComplete="new-password"
                  required
                  disabled={loading}
                />
              </div>

              <div className="form-group">
                <label htmlFor="confirmPassword">Confirm password</label>
                <input
                  id="confirmPassword"
                  type="password"
                  className="form-input"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder="Repeat your password"
                  autoComplete="new-password"
                  required
                  disabled={loading}
                />
              </div>

              {error && <div className="alert alert--error">{error}</div>}

              <button type="submit" className="btn btn--primary btn--block" disabled={loading}>
                {loading ? 'Creating account...' : 'Create account'}
              </button>
            </form>

            <p className="auth-footer">
              Already have an account? <Link to="/login">Sign in</Link>
            </p>
          </div>
        </section>
      </div>
    </div>
  );
}

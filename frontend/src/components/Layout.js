import React, { useEffect, useState } from 'react';
import { NavLink, useLocation, useNavigate } from 'react-router-dom';
import useAuth from '../hooks/useAuth';

const PAGE_META = {
  '/': {
    label: 'Dashboard',
    description: 'Monitor balances, pricing context, and recent account activity.',
  },
  '/buy': {
    label: 'Buy Gold',
    description: 'Submit a purchase order using the latest quote and secure checkout flow.',
  },
  '/sell': {
    label: 'Sell Gold',
    description: 'Convert your holdings back into EUR with the current live price.',
  },
  '/transactions': {
    label: 'Transactions',
    description: 'Review trade history, fees, and account movement in one place.',
  },
  '/insights': {
    label: 'AI Insights',
    description: 'See the latest generated market summaries and trading signals.',
  },
  '/settings': {
    label: 'Settings',
    description: 'Manage passwords, privacy tools, and account-level controls.',
  },
  '/admin': {
    label: 'Admin',
    description: 'Control tenants, pricing, fee rules, and operational actions.',
  },
};

export default function Layout({ children }) {
  const { user, isAdmin, logout } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const [navOpen, setNavOpen] = useState(false);
  const sessionTitle = isAdmin ? 'Admin workspace' : 'Trading workspace';
  const sessionCopy = isAdmin
    ? 'Operational controls and tenant management are available in this session.'
    : 'Balances, trading, and insights stay available in one protected shell.';

  const activeMeta = PAGE_META[location.pathname] || {
    label: 'Aurix Workspace',
    description: 'Secure multi-tenant gold trading workspace.',
  };

  useEffect(() => {
    setNavOpen(false);
  }, [location.pathname]);

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  const navItems = [
    { to: '/', label: 'Dashboard', icon: '◌' },
    { to: '/buy', label: 'Buy Gold', icon: '↗' },
    { to: '/sell', label: 'Sell Gold', icon: '↘' },
    { to: '/transactions', label: 'Transactions', icon: '≡' },
    { to: '/insights', label: 'Insights', icon: '✦' },
    { to: '/settings', label: 'Settings', icon: '⚙' },
  ];

  if (isAdmin) {
    navItems.push({ to: '/admin', label: 'Admin', icon: '⌘' });
  }

  return (
    <div className={`layout ${navOpen ? 'layout--nav-open' : ''}`}>
      <button
        type="button"
        className="sidebar-backdrop"
        aria-label="Close navigation"
        onClick={() => setNavOpen(false)}
      />
      <aside className="sidebar">
        <div className="sidebar-brand">
          <span className="brand-mark">A</span>
          <div className="brand-lockup">
            <span className="brand-text">Aurix</span>
            <span className="brand-subtitle">Digital gold workspace</span>
          </div>
        </div>
        <p className="sidebar-section-label">Workspace</p>
        <nav className="sidebar-nav">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === '/'}
              className={({ isActive }) =>
                `nav-link ${isActive ? 'nav-link--active' : ''}`
              }
            >
              <span className="nav-icon">{item.icon}</span>
              <span className="nav-link__copy">{item.label}</span>
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-footer">
          <div className="sidebar-status">
            <span className="sidebar-status__label">Session</span>
            <strong className="sidebar-status__value">{sessionTitle}</strong>
            <p className="sidebar-status__copy">{sessionCopy}</p>
          </div>
          <div className="sidebar-account">
            <p className="sidebar-caption">Signed in</p>
            <p className="sidebar-user">{user?.email || 'Authenticated user'}</p>
          </div>
        </div>
      </aside>
      <div className="main-wrapper">
        <header className="header">
          <div className="header-shell">
            <div className="header-top">
              <button
                type="button"
                className="sidebar-toggle"
                aria-label="Open navigation"
                aria-expanded={navOpen}
                onClick={() => setNavOpen((open) => !open)}
              >
                ≡
              </button>
              <div className="header-left">
                <p className="header-kicker">Aurix Console</p>
                <h2 className="header-title">{activeMeta.label}</h2>
                <p className="header-subtitle">{activeMeta.description}</p>
              </div>
            </div>

            <div className="header-right">
              <div className="header-meta">
                <span className="header-pill">Secure session</span>
                <span className={`header-pill ${isAdmin ? 'header-pill--filled' : ''}`}>
                  {isAdmin ? 'Admin role' : 'Client role'}
                </span>
              </div>
              <div className="header-user">
                <span className="header-label">Signed in as</span>
                <span className="header-email">{user?.email}</span>
              </div>
              <button type="button" className="btn btn--secondary btn--sm" onClick={handleLogout}>
                Log out
              </button>
            </div>
          </div>
        </header>
        <main className="main-content">
          <div className="main-shell">{children}</div>
        </main>
      </div>
    </div>
  );
}

import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import useAuth from '../hooks/useAuth';

export default function Layout({ children }) {
  const { user, isAdmin, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  const navItems = [
    { to: '/', label: 'Dashboard', icon: '◈' },
    { to: '/buy', label: 'Buy Gold', icon: '▲' },
    { to: '/sell', label: 'Sell Gold', icon: '▼' },
    { to: '/transactions', label: 'Transactions', icon: '☰' },
    { to: '/insights', label: 'Insights', icon: '◉' },
    { to: '/settings', label: 'Settings', icon: '⚙' },
  ];

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <span className="brand-icon">✦</span>
          <span className="brand-text">Aurix</span>
        </div>
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
              {item.label}
            </NavLink>
          ))}
          {isAdmin && (
            <NavLink
              to="/admin"
              className={({ isActive }) =>
                `nav-link ${isActive ? 'nav-link--active' : ''}`
              }
            >
              <span className="nav-icon">⛊</span>
              Admin
            </NavLink>
          )}
        </nav>
      </aside>
      <div className="main-wrapper">
        <header className="header">
          <div className="header-left">
            <h2 className="header-title">Gold Trading Platform</h2>
          </div>
          <div className="header-right">
            <span className="header-email">{user?.email}</span>
            {isAdmin && <span className="badge badge--admin">Admin</span>}
            <button className="btn btn--secondary btn--sm" onClick={handleLogout}>
              Logout
            </button>
          </div>
        </header>
        <main className="main-content">{children}</main>
      </div>
    </div>
  );
}

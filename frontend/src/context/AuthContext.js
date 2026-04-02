import React, { createContext, useState, useEffect, useCallback } from 'react';
import {
  login as apiLogin,
  register as apiRegister,
  logoutCall,
  setTokens,
  getAccessToken,
  getRefreshToken,
  clearTokens,
} from '../api/client';

export const AuthContext = createContext(null);

function decodeJwtPayload(token) {
  try {
    const payload = token.split('.')[1];
    const decoded = atob(payload.replace(/-/g, '+').replace(/_/g, '/'));
    return JSON.parse(decoded);
  } catch {
    return null;
  }
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  const applyToken = useCallback((token) => {
    if (!token) {
      setUser(null);
      setIsAuthenticated(false);
      setIsAdmin(false);
      return;
    }
    const payload = decodeJwtPayload(token);
    if (!payload) {
      clearTokens();
      setUser(null);
      setIsAuthenticated(false);
      setIsAdmin(false);
      return;
    }
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < now) {
      clearTokens();
      setUser(null);
      setIsAuthenticated(false);
      setIsAdmin(false);
      return;
    }
    const u = {
      sub: payload.sub,
      email: payload.email,
      tenant_id: payload.tenant_id,
      role: payload.role,
    };
    setUser(u);
    setIsAuthenticated(true);
    setIsAdmin(u.role === 'admin');
  }, []);

  useEffect(() => {
    const token = getAccessToken();
    applyToken(token);
    setLoading(false);
  }, [applyToken]);

  const loginFn = useCallback(
    async (tenantCode, email, password) => {
      const data = await apiLogin(tenantCode, email, password);
      setTokens(data.access_token, data.refresh_token);
      applyToken(data.access_token);
      return data;
    },
    [applyToken]
  );

  const registerFn = useCallback(
    async (tenantCode, email, password) => {
      const data = await apiRegister(tenantCode, email, password);
      setTokens(data.access_token, data.refresh_token);
      applyToken(data.access_token);
      return data;
    },
    [applyToken]
  );

  const logoutFn = useCallback(async () => {
    const refresh = getRefreshToken();
    try {
      if (refresh) await logoutCall(refresh);
    } catch {
      // ignore logout API errors
    }
    clearTokens();
    setUser(null);
    setIsAuthenticated(false);
    setIsAdmin(false);
  }, []);

  if (loading) {
    return <div className="loading-screen">Loading…</div>;
  }

  return (
    <AuthContext.Provider
      value={{ user, isAuthenticated, isAdmin, login: loginFn, register: registerFn, logout: logoutFn }}
    >
      {children}
    </AuthContext.Provider>
  );
}

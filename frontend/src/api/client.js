const BASE_URL = process.env.REACT_APP_API_URL || '';

export function setTokens(access, refresh) {
  localStorage.setItem('aurix_access_token', access);
  localStorage.setItem('aurix_refresh_token', refresh);
}

export function getAccessToken() {
  return localStorage.getItem('aurix_access_token');
}

export function getRefreshToken() {
  return localStorage.getItem('aurix_refresh_token');
}

export function clearTokens() {
  localStorage.removeItem('aurix_access_token');
  localStorage.removeItem('aurix_refresh_token');
}

async function attemptRefresh() {
  const refresh = getRefreshToken();
  if (!refresh) return false;

  try {
    const res = await fetch(`${BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refresh }),
    });

    if (!res.ok) return false;

    const data = await res.json();
    setTokens(data.access_token, data.refresh_token);
    return true;
  } catch {
    return false;
  }
}

export async function apiFetch(path, options = {}) {
  const url = `${BASE_URL}${path}`;
  const token = getAccessToken();

  const headers = {
    'Content-Type': 'application/json',
    ...options.headers,
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  let res = await fetch(url, { ...options, headers });

  if (res.status === 401 && token) {
    const refreshed = await attemptRefresh();
    if (refreshed) {
      headers['Authorization'] = `Bearer ${getAccessToken()}`;
      res = await fetch(url, { ...options, headers });
    }
  }

  const contentType = res.headers.get('content-type');
  let body = null;
  if (contentType && contentType.includes('application/json')) {
    body = await res.json();
  }

  if (!res.ok) {
    const message =
      body && body.error ? body.error.message : `Request failed (${res.status})`;
    const code = body && body.error ? body.error.code : 'unknown';
    const err = new Error(message);
    err.code = code;
    err.status = res.status;
    if (body && body.tenants) {
      err.tenants = body.tenants;
    }
    throw err;
  }

  return body;
}

// ─── Auth ───────────────────────────────────────────────────────────────────

export function register(tenantCode, email, password) {
  return apiFetch('/auth/register', {
    method: 'POST',
    body: JSON.stringify({ tenant_code: tenantCode, email, password }),
  });
}

export function login(email, password, tenantCode) {
  const body = { email, password };
  if (tenantCode) body.tenant_code = tenantCode;
  return apiFetch('/auth/login', {
    method: 'POST',
    body: JSON.stringify(body),
  });
}

export function refreshTokenCall(refreshToken) {
  return apiFetch('/auth/refresh', {
    method: 'POST',
    body: JSON.stringify({ refresh_token: refreshToken }),
  });
}

export function logoutCall(refreshToken) {
  return apiFetch('/auth/logout', {
    method: 'POST',
    body: JSON.stringify({ refresh_token: refreshToken }),
  });
}

export function changePassword(currentPassword, newPassword) {
  return apiFetch('/auth/change-password', {
    method: 'POST',
    body: JSON.stringify({
      current_password: currentPassword,
      new_password: newPassword,
    }),
  });
}

// ─── Wallet ─────────────────────────────────────────────────────────────────

export function getWallet() {
  return apiFetch('/wallet');
}

export function buyGold(grams, idempotencyKey) {
  return apiFetch('/wallet/buy', {
    method: 'POST',
    headers: { 'Idempotency-Key': idempotencyKey },
    body: JSON.stringify({ grams }),
  });
}

export function sellGold(grams, idempotencyKey) {
  return apiFetch('/wallet/sell', {
    method: 'POST',
    headers: { 'Idempotency-Key': idempotencyKey },
    body: JSON.stringify({ grams }),
  });
}

// ─── Transactions ───────────────────────────────────────────────────────────

export function getTransactions(cursor, limit = 20) {
  const params = new URLSearchParams({ limit: String(limit) });
  if (cursor) params.set('cursor', cursor);
  return apiFetch(`/transactions?${params.toString()}`);
}

// ─── Insights ───────────────────────────────────────────────────────────────

export function getInsights(cursor, limit = 10) {
  const params = new URLSearchParams({ limit: String(limit) });
  if (cursor) params.set('cursor', cursor);
  return apiFetch(`/insights?${params.toString()}`);
}

// ─── Privacy ────────────────────────────────────────────────────────────────

export function getPrivacyExport() {
  return apiFetch('/privacy/export');
}

export function requestErasure() {
  return apiFetch('/privacy/erasure', { method: 'POST' });
}

// ─── Admin ──────────────────────────────────────────────────────────────────

export function adminListTenants() {
  return apiFetch('/admin/tenants');
}

export function adminDeactivateTenant(tenantId) {
  return apiFetch(`/admin/tenants/${tenantId}/deactivate`, { method: 'POST' });
}

export function adminUpdateGoldPrice(priceEur) {
  return apiFetch('/admin/gold-price', {
    method: 'PUT',
    body: JSON.stringify({ price_eur: priceEur }),
  });
}

export function adminUpdateFeeConfig(tenantId, buyFeeRate, sellFeeRate, minFeeEurCents) {
  return apiFetch(`/admin/tenants/${tenantId}/fees`, {
    method: 'PUT',
    body: JSON.stringify({
      buy_fee_rate: buyFeeRate,
      sell_fee_rate: sellFeeRate,
      min_fee_eur_cents: minFeeEurCents,
    }),
  });
}

export function adminTriggerEtl() {
  return apiFetch('/admin/etl/trigger', { method: 'POST' });
}

# Aurix API Reference

Per-endpoint documentation for the Aurix digital gold trading API.

- **Base URL**: `http://localhost:8080`
- **OpenAPI Spec**: [openapi.json](../../priv/swagger/openapi.json)

---

## Common Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | Yes (on POST/PUT) | `application/json` |
| `Authorization` | Yes (protected routes) | `Bearer <jwt_access_token>` |
| `Idempotency-Key` | Required (wallet buy/sell) | Unique key to prevent duplicate processing |
| `X-Request-Id` | Optional | Client-provided request correlation ID |

## Standard Error Response

All error responses follow this structure:

```json
{
    "error": {
        "code": "error_code_snake_case",
        "message": "Human-readable description",
        "details": {}
    }
}
```

---

## Endpoints

### Authentication

| Method | Path | Description | Doc |
|--------|------|-------------|-----|
| POST | `/auth/register` | Create a new user account and wallet | [register.md](auth/register.md) |
| POST | `/auth/login` | Authenticate and receive tokens | [login.md](auth/login.md) |
| POST | `/auth/refresh` | Exchange refresh token for new token pair | [refresh.md](auth/refresh.md) |
| POST | `/auth/logout` | Revoke a refresh token | [logout.md](auth/logout.md) |
| POST | `/auth/change-password` | Change the authenticated user's password | [change-password.md](auth/change-password.md) |

### Wallet

| Method | Path | Description | Doc |
|--------|------|-------------|-----|
| GET | `/wallet` | Get the authenticated user's wallet | [view.md](wallet/view.md) |
| POST | `/wallet/buy` | Buy gold with EUR balance | [buy.md](wallet/buy.md) |
| POST | `/wallet/sell` | Sell gold for EUR balance | [sell.md](wallet/sell.md) |

### Transactions

| Method | Path | Description | Doc |
|--------|------|-------------|-----|
| GET | `/transactions` | List the user's transaction history | [list.md](transactions/list.md) |

### Insights

| Method | Path | Description | Doc |
|--------|------|-------------|-----|
| GET | `/insights` | Get AI-generated trading insights | [list.md](insights/list.md) |

### Privacy

| Method | Path | Description | Doc |
|--------|------|-------------|-----|
| GET | `/privacy/export` | Export all personal data for the user | [export.md](privacy/export.md) |
| POST | `/privacy/erasure-request` | Request account deletion and data erasure | [erasure.md](privacy/erasure.md) |

### Admin

| Method | Path | Description | Doc |
|--------|------|-------------|-----|
| GET | `/admin/tenants` | List all tenants | [list-tenants.md](admin/list-tenants.md) |
| POST | `/admin/tenants/:tenant_id/deactivate` | Deactivate a tenant | [deactivate-tenant.md](admin/deactivate-tenant.md) |
| POST | `/admin/gold-price` | Update the current gold price | [update-gold-price.md](admin/update-gold-price.md) |
| PUT | `/admin/tenants/:tenant_id/fees` | Update tenant fee configuration | [update-fee-config.md](admin/update-fee-config.md) |
| POST | `/admin/etl/trigger` | Manually trigger the ETL pipeline | [trigger-etl.md](admin/trigger-etl.md) |

### System

| Method | Path | Description | Doc |
|--------|------|-------------|-----|
| GET | `/health` | Health check for load balancers and monitoring | [health.md](system/health.md) |

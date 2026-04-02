# POST /auth/login

Authenticate and receive an access token and refresh token.

## Authentication

None.

## Request

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | Yes | `application/json` |

### Body

```json
{
    "email": "user@example.com",
    "password": "StrongPass123"
}
```

With optional tenant selection:

```json
{
    "tenant_code": "aurix-demo",
    "email": "user@example.com",
    "password": "StrongPass123"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | string | Yes | Valid email format |
| `password` | string | Yes | Non-empty |
| `tenant_code` | string | No | Specify tenant directly. If omitted, the system resolves the tenant automatically |

## Response

### Success 200

Returned when login succeeds (single tenant found or tenant_code provided):

```json
{
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2g...",
    "token_type": "Bearer",
    "expires_in": 900
}
```

### Tenant Selection Required 409

Returned when the email exists in multiple tenants and no `tenant_code` was provided:

```json
{
    "error": {
        "code": "tenant_selection_required",
        "message": "Multiple tenants found. Please select one."
    },
    "tenants": [
        { "tenant_code": "aurix-demo" },
        { "tenant_code": "partner-co" }
    ]
}
```

The client should display the tenant list and re-submit the login request with the selected `tenant_code`.

### Error Responses

| Status | Code | When |
|--------|------|------|
| 400 | `bad_request` | Missing email or password |
| 400 | `invalid_tenant` | Provided tenant_code not found |
| 401 | `invalid_credentials` | Wrong email or password |
| 403 | `account_disabled` | User account is soft-deleted |
| 403 | `tenant_inactive` | Tenant is deactivated |
| 409 | `tenant_selection_required` | Email exists in multiple tenants |

## Smart Login Flow

1. Client sends `email` + `password` (no `tenant_code`)
2. Backend looks up the email across all active tenants
3. **Single tenant match** → returns 200 with tokens
4. **Multiple tenants, single password match** → returns 200 with tokens for the matching tenant
5. **Multiple tenants, multiple password matches** → returns 409 with tenant list
6. Client picks a tenant and re-submits with `tenant_code`

## Rate Limiting

| Scope | Limit | Window |
|-------|-------|--------|
| Per IP | 10 | 1 minute |

## Notes

- `expires_in` is the access token lifetime in seconds (15 minutes).
- The refresh token should be stored securely by the client and used with `POST /auth/refresh` to obtain new tokens.
- `tenant_code` remains required for `POST /auth/register` — users must specify which organization to join.

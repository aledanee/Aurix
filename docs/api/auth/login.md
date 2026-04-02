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
    "tenant_code": "aurix-demo",
    "email": "user@example.com",
    "password": "StrongPass123"
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `tenant_code` | string | Yes | Must match an active tenant |
| `email` | string | Yes | Valid email format |
| `password` | string | Yes | Non-empty |

## Response

### Success 200

```json
{
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2g...",
    "token_type": "Bearer",
    "expires_in": 900
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 400 | `invalid_tenant` | Tenant code not found |
| 401 | `invalid_credentials` | Wrong email or password |
| 403 | `account_disabled` | User account is soft-deleted |
| 403 | `tenant_inactive` | Tenant is deactivated |

## Rate Limiting

| Scope | Limit | Window |
|-------|-------|--------|
| Per IP + tenant | 10 | 1 minute |

## Notes

- `expires_in` is the access token lifetime in seconds (15 minutes).
- The refresh token should be stored securely by the client and used with `POST /auth/refresh` to obtain new tokens.

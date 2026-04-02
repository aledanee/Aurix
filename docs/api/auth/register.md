# POST /auth/register

Create a new user account and wallet.

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
| `email` | string | Yes | Valid email format, unique within tenant |
| `password` | string | Yes | >= 10 chars, 1 uppercase, 1 lowercase, 1 digit |

## Response

### Success 201

```json
{
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "tenant_id": "660e8400-e29b-41d4-a716-446655440000",
    "wallet_id": "770e8400-e29b-41d4-a716-446655440000",
    "created_at": "2026-04-02T10:00:00Z"
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 400 | `invalid_tenant` | Tenant code not found |
| 400 | `invalid_email` | Email format is invalid |
| 400 | `invalid_password` | Password doesn't meet requirements |
| 403 | `tenant_inactive` | Tenant is deactivated |
| 409 | `email_taken` | Email already registered in this tenant |

## Rate Limiting

| Scope | Limit | Window |
|-------|-------|--------|
| Per IP + tenant | 5 | 1 minute |

## Notes

- A wallet with zero EUR and zero gold balances is automatically created for the new user.
- The user is scoped to the tenant identified by `tenant_code`.

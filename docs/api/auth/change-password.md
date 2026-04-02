# POST /auth/change-password

Change the authenticated user's password.

## Authentication

Required. JWT access token via `Authorization` header.

## Request

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | Yes | `application/json` |
| `Authorization` | Yes | `Bearer <jwt_access_token>` |

### Body

```json
{
    "current_password": "OldStrongPass123",
    "new_password": "NewStrongPass456"
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `current_password` | string | Yes | Must match the stored password |
| `new_password` | string | Yes | >= 10 chars, 1 uppercase, 1 lowercase, 1 digit; must differ from `current_password` |

## Response

### Success 204

No content.

### Error Responses

| Status | Code | When |
|--------|------|------|
| 400 | `invalid_password` | New password doesn't meet requirements |
| 401 | `unauthorized` | Missing or invalid JWT |
| 401 | `invalid_credentials` | Current password is wrong |

## Rate Limiting

No specific rate limit defined for this endpoint.

## Notes

- **Side effects**: All existing refresh tokens for the user are revoked and the current JWT is blacklisted.
- The client must re-authenticate with the new password after a successful change.

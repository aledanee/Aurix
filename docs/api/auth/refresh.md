# POST /auth/refresh

Exchange a refresh token for a new access token and refresh token pair.

## Authentication

None. The refresh token in the body serves as the credential.

## Request

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | Yes | `application/json` |

### Body

```json
{
    "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2g..."
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `refresh_token` | string | Yes | Must be a valid, non-expired, non-revoked refresh token |

## Response

### Success 200

```json
{
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "bmV3IHJlZnJlc2ggdG9rZW4...",
    "token_type": "Bearer",
    "expires_in": 900
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 401 | `token_expired` | Refresh token has expired |
| 401 | `token_revoked` | Refresh token was already revoked |
| 403 | `account_disabled` | User account is soft-deleted |

## Rate Limiting

No specific rate limit defined for this endpoint.

## Notes

- This endpoint implements **refresh token rotation**: the old refresh token is revoked and a new one is issued with each call.
- If a revoked refresh token is used, all tokens for that user may be revoked as a security measure (token reuse detection).

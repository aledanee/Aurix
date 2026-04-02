# POST /auth/logout

Revoke the current refresh token.

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
    "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2g..."
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `refresh_token` | string | Yes | The refresh token to revoke |

## Response

### Success 200

```json
{}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 401 | `unauthorized` | Missing or invalid JWT |

## Rate Limiting

No specific rate limit defined for this endpoint.

## Notes

- Returns 200 (not 204) with an empty JSON body.
- The specified refresh token is revoked and can no longer be used with `POST /auth/refresh`.

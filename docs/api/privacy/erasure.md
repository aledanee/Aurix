# POST /privacy/erasure-request

Request account deletion and data erasure (GDPR right to erasure).

## Authentication

Required. JWT access token via `Authorization` header.

## Request

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <jwt_access_token>` |

## Response

### Success 202

```json
{
    "status": "accepted",
    "message": "Your account has been disabled. Personal data will be erased according to our retention policy.",
    "request_id": "bb0e8400-e29b-41d4-a716-446655440000"
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 401 | `unauthorized` | Missing or invalid JWT |

## Rate Limiting

No specific rate limit defined for this endpoint.

## Notes

- The account is immediately disabled upon request.
- All refresh tokens for the user are revoked.
- Personal data is erased according to the data retention policy (not immediately, to allow for compliance review).
- The response may return 200 or 202 depending on whether erasure is processed synchronously or queued.

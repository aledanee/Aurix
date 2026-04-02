# GET /privacy/export

Export all personal data for the authenticated user (GDPR data portability).

## Authentication

Required. JWT access token via `Authorization` header.

## Request

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <jwt_access_token>` |

## Response

### Success 200

```json
{
    "user": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "email": "user@example.com",
        "created_at": "2026-04-01T08:00:00Z"
    },
    "wallet": {
        "gold_balance_grams": "12.50000000",
        "fiat_balance_eur": "8421.35"
    },
    "transactions": [
        {
            "id": "880e8400-e29b-41d4-a716-446655440000",
            "type": "buy",
            "gold_grams": "1.25000000",
            "gross_eur": "81.25",
            "created_at": "2026-04-02T10:00:00Z"
        }
    ],
    "insights": [],
    "exported_at": "2026-04-02T12:00:00Z"
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 401 | `unauthorized` | Missing or invalid JWT |

## Rate Limiting

No specific rate limit defined for this endpoint.

## Notes

- Returns all user profile data, wallet balances, transaction history, and insight snapshots in a single response.
- The `exported_at` timestamp indicates when the export was generated.

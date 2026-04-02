# GET /wallet

Get the authenticated user's wallet balances.

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
    "wallet_id": "770e8400-e29b-41d4-a716-446655440000",
    "tenant_id": "660e8400-e29b-41d4-a716-446655440000",
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "gold_balance_grams": "12.50000000",
    "fiat_balance_eur": "8421.35",
    "fiat_balance_eur_cents": 842135,
    "updated_at": "2026-04-02T10:30:00Z"
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 401 | `unauthorized` | Missing or invalid JWT |
| 404 | `wallet_not_found` | No wallet exists for this user |

## Rate Limiting

| Scope | Limit | Window |
|-------|-------|--------|
| Per user | 60 | 1 minute |

## Notes

- `fiat_balance_eur` is stored as integer cents internally but returned as a decimal string for display.
- `fiat_balance_eur_cents` is the raw integer cents value.
- `gold_balance_grams` is a decimal string with up to 8 decimal places.

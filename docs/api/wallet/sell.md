# POST /wallet/sell

Sell gold for EUR balance.

## Authentication

Required. JWT access token via `Authorization` header.

## Request

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | Yes | `application/json` |
| `Authorization` | Yes | `Bearer <jwt_access_token>` |
| `Idempotency-Key` | Yes | Unique key to prevent duplicate processing |

### Body

```json
{
    "grams": "0.50000000"
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `grams` | string | Yes | Positive decimal string, max 8 decimal places |

## Response

### Success 200

```json
{
    "transaction": {
        "id": "990e8400-e29b-41d4-a716-446655440000",
        "type": "sell",
        "gold_grams": "0.50000000",
        "price_eur_per_gram": "65.00000000",
        "gross_eur": "32.50",
        "fee_eur": "0.50",
        "net_eur": "32.00",
        "created_at": "2026-04-02T10:05:00Z"
    },
    "wallet": {
        "gold_balance_grams": "13.25000000",
        "fiat_balance_eur_cents": 837160
    }
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 400 | `invalid_amount` | Grams value is invalid, negative, or exceeds 8 decimal places |
| 401 | `unauthorized` | Missing or invalid JWT |
| 409 | `duplicate_request` | Idempotency key has already been used |
| 422 | `insufficient_gold` | Not enough gold balance for this sale |

## Rate Limiting

| Scope | Limit | Window |
|-------|-------|--------|
| Per user | 30 | 1 minute |

## Notes

- **Fee calculation (sell)**:
  ```
  gross_eur_cents = round(grams * price_per_gram * 100)
  fee_eur_cents   = max(min_fee_cents, round(gross_eur_cents * sell_fee_rate))
  net_eur_cents   = gross_eur_cents - fee_eur_cents
  ```
  The minimum fee is 50 cents (configurable per tenant).
- `net_eur` is computed at read time from stored integer cents. It is not stored as a separate column.
- Returns 200 (not 201) because the response includes both the created transaction and the updated wallet state.
- The `Idempotency-Key` header is required to ensure safe retries.

# POST /wallet/buy

Buy gold with EUR balance.

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
    "grams": "1.25000000"
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
        "id": "880e8400-e29b-41d4-a716-446655440000",
        "type": "buy",
        "gold_grams": "1.25000000",
        "price_eur_per_gram": "65.00000000",
        "gross_eur": "81.25",
        "fee_eur": "0.50",
        "total_eur": "81.75",
        "created_at": "2026-04-02T10:00:00Z"
    },
    "wallet": {
        "gold_balance_grams": "13.75000000",
        "fiat_balance_eur_cents": 833960
    }
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 400 | `invalid_amount` | Grams value is invalid, negative, or exceeds 8 decimal places |
| 401 | `unauthorized` | Missing or invalid JWT |
| 409 | `duplicate_request` | Idempotency key has already been used |
| 422 | `insufficient_balance` | Not enough EUR balance for this purchase |

## Rate Limiting

| Scope | Limit | Window |
|-------|-------|--------|
| Per user | 30 | 1 minute |

## Notes

- **Fee calculation (buy)**:
  ```
  gross_eur_cents = round(grams * price_per_gram * 100)
  fee_eur_cents   = max(min_fee_cents, round(gross_eur_cents * buy_fee_rate))
  total_eur_cents = gross_eur_cents + fee_eur_cents
  ```
  The minimum fee is 50 cents (configurable per tenant).
- `total_eur` and EUR display values are computed at read time from the stored integer cents. They are not stored as separate columns.
- Returns 200 (not 201) because the response includes both the created transaction and the updated wallet state.
- The `Idempotency-Key` header is required to ensure safe retries.

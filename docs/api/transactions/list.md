# GET /transactions

List the user's transaction history with cursor-based pagination.

## Authentication

Required. JWT access token via `Authorization` header.

## Request

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <jwt_access_token>` |

### Query Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `cursor` | string | — | Opaque pagination cursor from `next_cursor` |
| `limit` | integer | 20 | Items per page (1–100) |
| `type` | string | — | Filter by transaction type: `buy` or `sell` |

## Response

### Success 200

```json
{
    "items": [
        {
            "id": "880e8400-e29b-41d4-a716-446655440000",
            "type": "buy",
            "gold_grams": "1.25000000",
            "price_eur_per_gram": "65.00000000",
            "gross_eur": "81.25",
            "fee_eur": "0.50",
            "status": "posted",
            "created_at": "2026-04-02T10:00:00Z"
        },
        {
            "id": "990e8400-e29b-41d4-a716-446655440000",
            "type": "sell",
            "gold_grams": "0.50000000",
            "price_eur_per_gram": "65.00000000",
            "gross_eur": "32.50",
            "fee_eur": "0.50",
            "status": "posted",
            "created_at": "2026-04-02T10:05:00Z"
        }
    ],
    "next_cursor": "eyJjcmVhdGVkX2F0IjoiMjAyNi0wNC0wMlQxMDowMDowMFoifQ=="
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 401 | `unauthorized` | Missing or invalid JWT |

## Rate Limiting

| Scope | Limit | Window |
|-------|-------|--------|
| Per user | 60 | 1 minute |

## Notes

- Results are ordered by `created_at` descending.
- `next_cursor` is `null` when there are no more pages.
- Cursors are opaque to clients. They are internally encoded as `base64url(json({"created_at": "<ISO8601>", "id": "<uuid>"}))`.

# POST /admin/gold-price

Update the current gold price used for buy/sell calculations.

## Authentication

Required. Requires admin role.

## Request

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | Yes | `application/json` |
| `Authorization` | Yes | `Bearer <jwt_access_token>` |

### Body

```json
{
    "price_eur": "72.50"
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `price_eur` | string | Yes | Positive decimal value |

## Response

### Success 200

```json
{
    "status": "updated",
    "price_eur": "72.50"
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 400 | `bad_request` | Invalid or negative price value |
| 401 | `unauthorized` | Missing or invalid JWT |
| 403 | `forbidden` | User does not have admin role |

## Rate Limiting

No specific rate limit defined for this endpoint.

## Notes

- The new price takes effect immediately for all subsequent buy/sell transactions across all tenants.
- The price is specified as a EUR-per-gram decimal string.

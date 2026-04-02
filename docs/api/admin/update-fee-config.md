# PUT /admin/tenants/:tenant_id/fees

Update the fee configuration for a specific tenant.

## Authentication

Required. Requires admin role.

## Request

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | Yes | `application/json` |
| `Authorization` | Yes | `Bearer <jwt_access_token>` |

### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `tenant_id` | uuid | The ID of the tenant to update fees for |

### Body

```json
{
    "buy_fee_rate": "0.015",
    "sell_fee_rate": "0.015",
    "min_fee_eur_cents": 50
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `buy_fee_rate` | string | Yes | Decimal rate (e.g., `"0.015"` for 1.5%) |
| `sell_fee_rate` | string | Yes | Decimal rate (e.g., `"0.015"` for 1.5%) |
| `min_fee_eur_cents` | integer | Yes | Minimum fee in EUR cents (e.g., `50` for €0.50) |

## Response

### Success 200

```json
{
    "status": "updated",
    "tenant_id": "660e8400-e29b-41d4-a716-446655440000"
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 400 | `bad_request` | Invalid fee rate or min fee value |
| 401 | `unauthorized` | Missing or invalid JWT |
| 403 | `forbidden` | User does not have admin role |
| 404 | `not_found` | Tenant with given ID does not exist |

## Rate Limiting

No specific rate limit defined for this endpoint.

## Notes

- Fee rates are decimal values representing percentages (e.g., `"0.015"` = 1.5%).
- `min_fee_eur_cents` is the floor fee applied when the calculated fee is below the minimum.
- Changes take effect immediately for all subsequent transactions under the tenant.

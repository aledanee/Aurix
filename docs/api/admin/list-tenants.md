# GET /admin/tenants

List all tenants in the system.

## Authentication

Required. Requires admin role.

## Request

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <jwt_access_token>` |

## Response

### Success 200

```json
{
    "items": [
        {
            "id": "660e8400-e29b-41d4-a716-446655440000",
            "code": "aurix-demo",
            "name": "Aurix Demo",
            "status": "active"
        },
        {
            "id": "770e8400-e29b-41d4-a716-446655440001",
            "code": "partner-bank",
            "name": "Partner Bank",
            "status": "active"
        }
    ]
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 401 | `unauthorized` | Missing or invalid JWT |
| 403 | `forbidden` | User does not have admin role |

## Rate Limiting

No specific rate limit defined for this endpoint.

## Notes

- Returns all tenants regardless of status (active and deactivated).

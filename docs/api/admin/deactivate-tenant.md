# POST /admin/tenants/:tenant_id/deactivate

Deactivate a tenant, preventing all users under that tenant from logging in or performing operations.

## Authentication

Required. Requires admin role.

## Request

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <jwt_access_token>` |

### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `tenant_id` | uuid | The ID of the tenant to deactivate |

## Response

### Success 200

```json
{
    "status": "deactivated",
    "tenant_id": "660e8400-e29b-41d4-a716-446655440000"
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 401 | `unauthorized` | Missing or invalid JWT |
| 403 | `forbidden` | User does not have admin role |
| 404 | `not_found` | Tenant with given ID does not exist |

## Rate Limiting

No specific rate limit defined for this endpoint.

## Notes

- Deactivated tenants' users will receive `403 tenant_inactive` on all authenticated requests.
- This operation does not delete any data — the tenant and its users remain in the database.

# POST /admin/etl/trigger

Manually trigger the ETL pipeline to generate insight snapshots.

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
    "status": "triggered"
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

- The ETL pipeline runs asynchronously. This endpoint triggers it and returns immediately.
- The pipeline collects transaction data, computes signals, calls the LLM adapter for insight generation, and stores the resulting snapshots.
- Under normal operation, the ETL is triggered automatically by the scheduler. This endpoint is for manual/on-demand runs.

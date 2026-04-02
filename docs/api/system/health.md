# GET /health

Health check endpoint for load balancers and monitoring.

## Authentication

None.

## Request

### Headers

No required headers.

## Response

### Success 200

Returned when all components are healthy.

```json
{
    "status": "healthy",
    "components": {
        "api": "up",
        "database": "up",
        "redis": "up"
    },
    "timestamp": "2026-04-02T10:00:00Z"
}
```

### Degraded 503

Returned when one or more components are down.

```json
{
    "status": "degraded",
    "components": {
        "api": "up",
        "database": "up",
        "redis": "down"
    },
    "timestamp": "2026-04-02T10:00:00Z"
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 503 | — | One or more backend components are unreachable |

## Rate Limiting

No rate limit on this endpoint.

## Notes

- Returns 200 if all components are healthy, 503 if any component is degraded.
- Components checked: API server, PostgreSQL database, Redis cache.
- Intended for use by load balancers, Kubernetes probes, and monitoring systems.

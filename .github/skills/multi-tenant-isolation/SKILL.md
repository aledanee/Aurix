---
name: multi-tenant-isolation
description: "Multi-tenant isolation patterns for Aurix. Use when: writing queries that access tenant-scoped data, implementing tenant resolution, extracting tenant context from JWT, or verifying tenant isolation in code reviews and tests."
---

# Multi-Tenant Isolation for Aurix

## When to Use
- Writing any query that touches tenant-scoped tables
- Implementing tenant resolution from JWT or request body
- Reviewing code for tenant data leaks
- Writing tests for tenant isolation

## Core Principle

**Every tenant-scoped query MUST include `tenant_id` in the WHERE clause.** No exceptions.

## Tenant-Scoped Tables

All of these tables have a `tenant_id` column:
- `users`
- `wallets`
- `transactions`
- `insight_snapshots`
- `outbox_events`
- `refresh_tokens`
- `tenant_fee_config`

The only table without `tenant_id` is `tenants` itself.

## Tenant Context Sources

| Endpoint Type | Source of tenant_id |
|---------------|---------------------|
| Authenticated (JWT required) | JWT claims — `tenant_id` from decoded token |
| Public (register, login) | Request body `tenant_code` → resolve to `tenant_id` via DB lookup |

**CRITICAL:** On authenticated endpoints, tenant_id comes EXCLUSIVELY from JWT claims. Never from request body, query params, or URL path.

## Repository Pattern

Every repo function that touches tenant-scoped data takes `TenantId` as the first parameter:

```erlang
%% CORRECT
-spec get_by_email(TenantId :: binary(), Email :: binary()) ->
    {ok, map()} | {error, not_found}.
get_by_email(TenantId, Email) ->
    SQL = "SELECT * FROM users WHERE tenant_id = $1 AND email = $2 AND deleted_at IS NULL",
    case pgapp:equery(SQL, [TenantId, Email]) of
        {ok, _, [Row]} -> {ok, row_to_map(Row)};
        {ok, _, []}    -> {error, not_found}
    end.

%% WRONG — missing tenant_id
get_by_email(Email) ->
    SQL = "SELECT * FROM users WHERE email = $1",
    ...
```

## SQL Checklist

For every SQL query:
1. Does the table have `tenant_id`? → Include it in WHERE
2. Is this a JOIN? → Include `tenant_id` on ALL joined tables
3. Is this an INSERT? → Include `tenant_id` in the values
4. Is this an INDEX scan? → Composite index starts with `tenant_id`

## Index Pattern

```sql
-- CORRECT: tenant_id first
CREATE INDEX idx_users_tenant_email ON users (tenant_id, email);

-- WRONG: email first (won't efficiently filter by tenant)
CREATE INDEX idx_users_email ON users (email);
```

## Tenant Resolution Flow

### Registration/Login (public endpoints)
```
1. Client sends tenant_code in request body
2. Server: SELECT * FROM tenants WHERE code = $1 AND status = 'active'
3. If not found → 400 invalid_tenant
4. If inactive → 403 tenant_inactive
5. Use tenant.id for all subsequent queries
```

### Authenticated endpoints
```
1. JWT middleware extracts and validates token
2. Extract tenant_id from JWT claims
3. Pass tenant_id to service → repo
4. Never override tenant_id from any other source
```

## Testing Tenant Isolation

```erlang
%% Create two test tenants
TenantA = create_test_tenant("tenant-a"),
TenantB = create_test_tenant("tenant-b"),

%% Create user in tenant A
UserA = create_test_user(TenantA, "user@test.com"),

%% Verify user is NOT visible in tenant B
{error, not_found} = aurix_repo_user:get_by_email(TenantB, "user@test.com"),

%% Verify user IS visible in tenant A
{ok, _} = aurix_repo_user:get_by_email(TenantA, "user@test.com").
```

## Anti-Patterns to Catch

| Anti-Pattern | Fix |
|---|---|
| Query without `tenant_id` in WHERE | Add `AND tenant_id = $N` |
| tenant_id from request body on authenticated route | Use JWT claims only |
| Cross-tenant JOIN without tenant_id match | Add `ON a.tenant_id = b.tenant_id` |
| Index without tenant_id prefix | Rebuild with tenant_id first |
| Service function missing TenantId param | Add as first parameter |

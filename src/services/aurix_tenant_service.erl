-module(aurix_tenant_service).

-export([resolve_active_tenant/1]).

%% Resolves a tenant code to an active tenant record.
-spec resolve_active_tenant(TenantCode :: binary()) ->
    {ok, map()} | {error, invalid_tenant | tenant_inactive}.
resolve_active_tenant(TenantCode) ->
    case aurix_repo_tenant:get_by_code(TenantCode) of
        {ok, #{status := <<"active">>} = Tenant} ->
            {ok, Tenant};
        {ok, _Inactive} ->
            {error, tenant_inactive};
        {error, not_found} ->
            {error, invalid_tenant}
    end.

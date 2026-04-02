-module(aurix_repo_tenant).

-export([get_by_code/1, list_all/0, update_status/2]).

%% Looks up a tenant by its unique code.
%% Not tenant-scoped (tenants table has no tenant_id).
-spec get_by_code(Code :: binary()) -> {ok, map()} | {error, not_found}.
get_by_code(Code) ->
    SQL = "SELECT id, code, name, status, created_at FROM tenants WHERE code = $1",
    case pgapp:equery(SQL, [Code]) of
        {ok, _Cols, [Row]} ->
            {ok, tenant_row_to_map(Row)};
        {ok, _Cols, []} ->
            {error, not_found}
    end.

%% Lists all tenants ordered by creation date (newest first).
%% Not tenant-scoped (tenants table has no tenant_id).
-spec list_all() -> {ok, [map()]}.
list_all() ->
    SQL = "SELECT id, code, name, status, created_at FROM tenants ORDER BY created_at DESC",
    case pgapp:equery(SQL, []) of
        {ok, _Cols, Rows} ->
            {ok, [tenant_row_to_map(Row) || Row <- Rows]}
    end.

%% Updates a tenant's status.
%% Not tenant-scoped (tenants table has no tenant_id).
-spec update_status(TenantId :: binary(), Status :: binary()) -> ok | {error, not_found}.
update_status(TenantId, Status) ->
    SQL = "UPDATE tenants SET status = $2 WHERE id = $1",
    case pgapp:equery(SQL, [TenantId, Status]) of
        {ok, 1} -> ok;
        {ok, 0} -> {error, not_found}
    end.

%% Internal
tenant_row_to_map({Id, Code, Name, Status, CreatedAt}) ->
    #{
        id => Id,
        code => Code,
        name => Name,
        status => Status,
        created_at => CreatedAt
    }.

-module(aurix_repo_tenant).

-export([get_by_code/1]).

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

%% Internal
tenant_row_to_map({Id, Code, Name, Status, CreatedAt}) ->
    #{
        id => Id,
        code => Code,
        name => Name,
        status => Status,
        created_at => CreatedAt
    }.

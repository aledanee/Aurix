-module(aurix_repo_user).

-export([create/4, create/5, get_by_email/2, get_by_id/2, update_password_hash/3, soft_delete/2]).

%% Creates a new user. Returns the generated user ID.
-spec create(TenantId :: binary(), Email :: binary(), PasswordHash :: binary(), UserId :: binary()) ->
    {ok, binary()} | {error, email_taken} | {error, term()}.
create(TenantId, Email, PasswordHash, UserId) ->
    SQL = "INSERT INTO users (id, tenant_id, email, password_hash, status, created_at) "
          "VALUES ($1, $2, $3, $4, 'active', now())",
    case pgapp:equery(SQL, [UserId, TenantId, Email, PasswordHash]) of
        {ok, 1} ->
            {ok, UserId};
        {error, Error} ->
            case is_unique_violation(Error) of
                true -> {error, email_taken};
                false -> {error, Error}
            end
    end.

%% Transactional variant — uses an existing connection.
-spec create(pid(), binary(), binary(), binary(), binary()) -> {ok, binary()} | {error, email_taken}.
create(Conn, TenantId, Email, PasswordHash, UserId) ->
    SQL = "INSERT INTO users (id, tenant_id, email, password_hash, status, created_at) "
          "VALUES ($1, $2, $3, $4, 'active', now())",
    case aurix_db:equery(Conn, SQL, [UserId, TenantId, Email, PasswordHash]) of
        {ok, 1} ->
            {ok, UserId};
        {error, Error} ->
            case is_unique_violation(Error) of
                true -> {error, email_taken};
                false -> {error, Error}
            end
    end.

%% Finds an active user by email within a tenant.
-spec get_by_email(TenantId :: binary(), Email :: binary()) -> {ok, map()} | {error, not_found}.
get_by_email(TenantId, Email) ->
    SQL = "SELECT id, tenant_id, email, password_hash, status, created_at, role "
          "FROM users WHERE tenant_id = $1 AND email = $2 AND deleted_at IS NULL",
    case pgapp:equery(SQL, [TenantId, Email]) of
        {ok, _Cols, [Row]} ->
            {ok, user_row_to_map(Row)};
        {ok, _Cols, []} ->
            {error, not_found}
    end.

%% Finds a user by ID within a tenant.
-spec get_by_id(TenantId :: binary(), UserId :: binary()) -> {ok, map()} | {error, not_found}.
get_by_id(TenantId, UserId) ->
    SQL = "SELECT id, tenant_id, email, password_hash, status, created_at, role "
          "FROM users WHERE tenant_id = $1 AND id = $2 AND deleted_at IS NULL",
    case pgapp:equery(SQL, [TenantId, UserId]) of
        {ok, _Cols, [Row]} ->
            {ok, user_row_to_map(Row)};
        {ok, _Cols, []} ->
            {error, not_found}
    end.

%% Updates a user's password hash.
-spec update_password_hash(TenantId :: binary(), UserId :: binary(), NewHash :: binary()) ->
    ok | {error, not_found}.
update_password_hash(TenantId, UserId, NewHash) ->
    SQL = "UPDATE users SET password_hash = $3 WHERE tenant_id = $1 AND id = $2 AND deleted_at IS NULL",
    case pgapp:equery(SQL, [TenantId, UserId, NewHash]) of
        {ok, 1} -> ok;
        {ok, 0} -> {error, not_found}
    end.

%% Soft-deletes a user (sets status to inactive and deleted_at).
-spec soft_delete(TenantId :: binary(), UserId :: binary()) -> ok | {error, not_found}.
soft_delete(TenantId, UserId) ->
    SQL = "UPDATE users SET status = 'inactive', deleted_at = now() WHERE tenant_id = $1 AND id = $2 AND deleted_at IS NULL",
    case pgapp:equery(SQL, [TenantId, UserId]) of
        {ok, 1} -> ok;
        {ok, 0} -> {error, not_found}
    end.

%% Internal
user_row_to_map({Id, TenantId, Email, PasswordHash, Status, CreatedAt, Role}) ->
    #{
        id => Id,
        tenant_id => TenantId,
        email => Email,
        password_hash => PasswordHash,
        status => Status,
        created_at => CreatedAt,
        role => Role
    }.

is_unique_violation({error, _Severity, Code, _Msg, _Detail}) ->
    Code =:= <<"23505">>;
is_unique_violation({error, _Severity, Code, _Msg, _Detail, _Extra}) ->
    Code =:= <<"23505">>;
is_unique_violation(_) ->
    false.

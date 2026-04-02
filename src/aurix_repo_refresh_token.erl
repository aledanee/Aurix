-module(aurix_repo_refresh_token).

-export([create/5, get_by_hash/1, get_by_hash_any/1, revoke/1, revoke_all_for_user/2]).

%% Creates a new refresh token record.
-spec create(Id :: binary(), TenantId :: binary(), UserId :: binary(),
             TokenHash :: binary(), ExpiresAt :: binary()) -> ok.
create(Id, TenantId, UserId, TokenHash, ExpiresAt) ->
    SQL = "INSERT INTO refresh_tokens (id, tenant_id, user_id, token_hash, expires_at, created_at) "
          "VALUES ($1, $2, $3, $4, $5, now())",
    {ok, 1} = pgapp:equery(SQL, [Id, TenantId, UserId, TokenHash, ExpiresAt]),
    ok.

%% Finds a valid (non-revoked, non-expired) refresh token by its hash.
-spec get_by_hash(TokenHash :: binary()) -> {ok, map()} | {error, not_found}.
get_by_hash(TokenHash) ->
    SQL = "SELECT id, tenant_id, user_id, token_hash, expires_at, revoked_at, created_at "
          "FROM refresh_tokens WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > now()",
    case pgapp:equery(SQL, [TokenHash]) of
        {ok, _Cols, [Row]} ->
            {ok, refresh_token_row_to_map(Row)};
        {ok, _Cols, []} ->
            {error, not_found}
    end.

%% Finds a refresh token by hash regardless of revoked/expired status.
-spec get_by_hash_any(TokenHash :: binary()) -> {ok, map()} | {error, not_found}.
get_by_hash_any(TokenHash) ->
    SQL = "SELECT id, tenant_id, user_id, token_hash, expires_at, revoked_at, created_at "
          "FROM refresh_tokens WHERE token_hash = $1 ORDER BY created_at DESC LIMIT 1",
    case pgapp:equery(SQL, [TokenHash]) of
        {ok, _Cols, [Row]} ->
            {ok, refresh_token_row_to_map(Row)};
        {ok, _Cols, []} ->
            {error, not_found}
    end.

%% Revokes a single refresh token by its ID.
-spec revoke(TokenId :: binary()) -> ok.
revoke(TokenId) ->
    SQL = "UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1 AND revoked_at IS NULL",
    pgapp:equery(SQL, [TokenId]),
    ok.

%% Revokes all refresh tokens for a user (e.g., on password change).
-spec revoke_all_for_user(TenantId :: binary(), UserId :: binary()) -> ok.
revoke_all_for_user(TenantId, UserId) ->
    SQL = "UPDATE refresh_tokens SET revoked_at = now() WHERE tenant_id = $1 AND user_id = $2 AND revoked_at IS NULL",
    pgapp:equery(SQL, [TenantId, UserId]),
    ok.

%% Internal
refresh_token_row_to_map({Id, TenantId, UserId, TokenHash, ExpiresAt, RevokedAt, CreatedAt}) ->
    #{
        id => Id,
        tenant_id => TenantId,
        user_id => UserId,
        token_hash => TokenHash,
        expires_at => ExpiresAt,
        revoked_at => RevokedAt,
        created_at => CreatedAt
    }.

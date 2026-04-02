-module(aurix_auth_service).

-export([register/3, login/3, refresh/1, logout/1, change_password/4]).

%%====================================================================
%% API
%%====================================================================

%% US-1.1 Register a new account
-spec register(TenantCode :: binary(), Email :: binary(), Password :: binary()) ->
    {ok, map()} | {error, atom()}.
register(TenantCode, Email, Password) ->
    case aurix_tenant_service:resolve_active_tenant(TenantCode) of
        {ok, Tenant} ->
            TenantId = maps:get(id, Tenant),
            case validate_password(Password) of
                ok ->
                    PasswordHash = hash_password(Password),
                    UserId = generate_uuid(),
                    WalletId = generate_uuid(),
                    Result = aurix_db:transaction(fun(Conn) ->
                        case aurix_repo_user:create(Conn, TenantId, Email, PasswordHash, UserId) of
                            {ok, UserId} ->
                                {ok, _} = aurix_repo_wallet:create(Conn, TenantId, UserId, WalletId),
                                {ok, #{
                                    user_id => UserId,
                                    email => Email,
                                    tenant_id => TenantId,
                                    wallet_id => WalletId,
                                    created_at => iso8601_now()
                                }};
                            {error, email_taken} ->
                                {error, email_taken}
                        end
                    end),
                    case Result of
                        {ok, Data} ->
                            logger:info(#{action => <<"auth.register">>, tenant_id => TenantId, email => mask_email(Email)}),
                            {ok, Data};
                        Error -> Error
                    end;
                {error, Reason} ->
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

%% US-1.2 Login
-spec login(TenantCode :: binary(), Email :: binary(), Password :: binary()) ->
    {ok, map()} | {error, atom()}.
login(TenantCode, Email, Password) ->
    case aurix_tenant_service:resolve_active_tenant(TenantCode) of
        {ok, Tenant} ->
            TenantId = maps:get(id, Tenant),
            case aurix_repo_user:get_by_email(TenantId, Email) of
                {ok, User} ->
                    StoredHash = maps:get(password_hash, User),
                    case verify_password(Password, StoredHash) of
                        true ->
                            case maps:get(status, User) of
                                <<"active">> ->
                                    UserId = maps:get(id, User),
                                    UserEmail = maps:get(email, User),
                                    Role = maps:get(role, User, <<"user">>),
                                    maybe_migrate_hash(TenantId, UserId, Password, StoredHash),
                                    {ok, AccessToken} = aurix_jwt:sign_access_token(UserId, TenantId, UserEmail, Role),
                                    {ok, RefreshToken, RefreshHash} = generate_refresh_token(),
                                    RefreshId = generate_uuid(),
                                    ExpiresAt = refresh_expiry_timestamp(),
                                    ok = aurix_repo_refresh_token:create(RefreshId, TenantId, UserId, RefreshHash, ExpiresAt),
                                    logger:info(#{action => <<"auth.login">>, tenant_id => TenantId, user_id => UserId, email => mask_email(Email), result => <<"success">>}),
                                    {ok, #{
                                        access_token => AccessToken,
                                        refresh_token => RefreshToken,
                                        token_type => <<"Bearer">>,
                                        expires_in => application:get_env(aurix, jwt_access_ttl_sec, 900)
                                    }};
                                _ ->
                                    logger:warning(#{action => <<"auth.login">>, tenant_id => TenantId, email => mask_email(Email), result => <<"account_disabled">>}),
                                    {error, account_disabled}
                            end;
                        false ->
                            logger:info(#{action => <<"auth.login">>, tenant_id => TenantId, email => mask_email(Email), result => <<"failed">>}),
                            {error, invalid_credentials}
                    end;
                {error, not_found} ->
                    %% Hash a dummy password to prevent timing attacks
                    _ = hash_password(<<"dummy_password_for_timing">>),
                    logger:info(#{action => <<"auth.login">>, tenant_id => TenantId, email => mask_email(Email), result => <<"failed">>}),
                    {error, invalid_credentials}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

%% US-1.3 Refresh token
-spec refresh(RefreshToken :: binary()) -> {ok, map()} | {error, atom()}.
refresh(RefreshToken) ->
    Hash = hash_refresh_token(RefreshToken),
    case aurix_repo_refresh_token:get_by_hash(Hash) of
        {ok, TokenRecord} ->
            %% Revoke old token (rotation)
            ok = aurix_repo_refresh_token:revoke(maps:get(id, TokenRecord)),
            %% Issue new tokens
            TenantId = maps:get(tenant_id, TokenRecord),
            UserId = maps:get(user_id, TokenRecord),
            case aurix_repo_user:get_by_id(TenantId, UserId) of
                {ok, User} ->
                    case maps:get(status, User) of
                        <<"active">> ->
                            Email = maps:get(email, User),
                            Role = maps:get(role, User, <<"user">>),
                            {ok, AccessToken} = aurix_jwt:sign_access_token(UserId, TenantId, Email, Role),
                            {ok, NewRefresh, NewHash} = generate_refresh_token(),
                            NewRefreshId = generate_uuid(),
                            ExpiresAt = refresh_expiry_timestamp(),
                            ok = aurix_repo_refresh_token:create(NewRefreshId, TenantId, UserId, NewHash, ExpiresAt),
                            logger:info(#{action => <<"auth.refresh">>, tenant_id => TenantId, user_id => UserId}),
                            {ok, #{
                                access_token => AccessToken,
                                refresh_token => NewRefresh,
                                token_type => <<"Bearer">>,
                                expires_in => application:get_env(aurix, jwt_access_ttl_sec, 900)
                            }};
                        _ ->
                            logger:info(#{action => <<"auth.refresh">>, result => <<"failed">>, reason => <<"account_disabled">>}),
                            {error, account_disabled}
                    end;
                {error, not_found} ->
                    logger:info(#{action => <<"auth.refresh">>, result => <<"failed">>, reason => <<"unauthorized">>}),
                    {error, unauthorized}
            end;
        {error, not_found} ->
            %% Check if the token exists but is expired or revoked
            case aurix_repo_refresh_token:get_by_hash_any(Hash) of
                {ok, Record} ->
                    case maps:get(revoked_at, Record) of
                        V when V =/= null, V =/= undefined ->
                            logger:info(#{action => <<"auth.refresh">>, result => <<"failed">>, reason => <<"token_revoked">>}),
                            {error, token_revoked};
                        _ ->
                            logger:info(#{action => <<"auth.refresh">>, result => <<"failed">>, reason => <<"token_expired">>}),
                            {error, token_expired}
                    end;
                {error, not_found} ->
                    logger:info(#{action => <<"auth.refresh">>, result => <<"failed">>, reason => <<"unauthorized">>}),
                    {error, unauthorized}
            end
    end.

%% US-1.4 Logout (revoke refresh token)
-spec logout(RefreshToken :: binary()) -> ok | {error, atom()}.
logout(RefreshToken) ->
    Hash = hash_refresh_token(RefreshToken),
    case aurix_repo_refresh_token:get_by_hash(Hash) of
        {ok, TokenRecord} ->
            ok = aurix_repo_refresh_token:revoke(maps:get(id, TokenRecord)),
            ok;
        {error, not_found} ->
            {error, unauthorized}
    end.

%% US-1.5 Change password
-spec change_password(TenantId :: binary(), UserId :: binary(),
                      CurrentPassword :: binary(), NewPassword :: binary()) ->
    ok | {error, atom()}.
change_password(TenantId, UserId, CurrentPassword, NewPassword) ->
    case aurix_repo_user:get_by_id(TenantId, UserId) of
        {ok, User} ->
            StoredHash = maps:get(password_hash, User),
            case verify_password(CurrentPassword, StoredHash) of
                true ->
                    case validate_password(NewPassword) of
                        ok ->
                            case CurrentPassword =:= NewPassword of
                                true ->
                                    {error, password_unchanged};
                                false ->
                                    NewHash = hash_password(NewPassword),
                                    ok = aurix_repo_user:update_password_hash(TenantId, UserId, NewHash),
                                    ok = aurix_repo_refresh_token:revoke_all_for_user(TenantId, UserId),
                                    ok = aurix_jwt_blacklist:blacklist_user(UserId),
                                    logger:info(#{action => <<"auth.change_password">>, tenant_id => TenantId, user_id => UserId}),
                                    ok
                            end;
                        {error, Reason} ->
                            {error, Reason}
                    end;
                false ->
                    {error, invalid_credentials}
            end;
        {error, not_found} ->
            {error, not_found}
    end.

%%====================================================================
%% Internal
%%====================================================================

%% Password validation: min 10 chars, max 128, uppercase, lowercase, digit
validate_password(Password) when is_binary(Password) ->
    Len = byte_size(Password),
    Str = binary_to_list(Password),
    HasUpper = lists:any(fun(C) -> C >= $A andalso C =< $Z end, Str),
    HasLower = lists:any(fun(C) -> C >= $a andalso C =< $z end, Str),
    HasDigit = lists:any(fun(C) -> C >= $0 andalso C =< $9 end, Str),
    case Len >= 10 andalso Len =< 128 andalso HasUpper andalso HasLower andalso HasDigit of
        true -> ok;
        false -> {error, invalid_password}
    end;
validate_password(_) ->
    {error, invalid_password}.

%% Hash password with bcrypt cost-12
hash_password(Password) when is_binary(Password) ->
    {ok, Salt} = bcrypt:gen_salt(12),
    {ok, Hash} = bcrypt:hashpw(binary_to_list(Password), Salt),
    list_to_binary(Hash).

%% Verify password against stored hash (bcrypt)
verify_password(Password, StoredHash) when is_binary(Password), is_binary(StoredHash) ->
    case StoredHash of
        <<"$2", _/binary>> ->
            {ok, StoredHash} =:= bcrypt:hashpw(binary_to_list(Password), binary_to_list(StoredHash));
        _ ->
            false
    end.

%% Hash migration no longer needed — bcrypt is the sole hasher
maybe_migrate_hash(_TenantId, _UserId, _Password, _StoredHash) ->
    ok.

%% Generate a random refresh token and its SHA-256 hash
generate_refresh_token() ->
    Token = base64:encode(crypto:strong_rand_bytes(32)),
    Hash = hash_refresh_token(Token),
    {ok, Token, Hash}.

%% Hash a refresh token for storage
hash_refresh_token(Token) ->
    base64:encode(crypto:hash(sha256, Token)).

%% Compute refresh token expiry as an ISO 8601 timestamp
refresh_expiry_timestamp() ->
    TTL = application:get_env(aurix, jwt_refresh_ttl_sec, 604800),
    ExpiresUnix = erlang:system_time(second) + TTL,
    {{Y, Mo, D}, {H, Mi, S}} = calendar:system_time_to_universal_time(ExpiresUnix, second),
    iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
                                    [Y, Mo, D, H, Mi, S])).

%% Generate a UUID v4 as binary string
generate_uuid() ->
    uuid:uuid_to_string(uuid:get_v4_urandom(), binary_standard).

%% ISO 8601 UTC timestamp
iso8601_now() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:universal_time(),
    iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
                                    [Y, Mo, D, H, Mi, S])).

mask_email(Email) when is_binary(Email) ->
    case binary:split(Email, <<"@">>) of
        [Local, Domain] when byte_size(Local) > 1 ->
            <<First:1/binary, _/binary>> = Local,
            <<First/binary, "***@", Domain/binary>>;
        _ ->
            <<"***">>
    end.

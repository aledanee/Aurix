-module(aurix_jwt).

-export([sign_access_token/3, sign_access_token/4, verify_token/1, get_secret/0]).

%%====================================================================
%% API
%%====================================================================

%% Signs an access token with sub, tenant_id, email claims (backward-compatible, defaults role to <<"user">>).
-spec sign_access_token(UserId :: binary(), TenantId :: binary(), Email :: binary()) ->
    {ok, Token :: binary()}.
sign_access_token(UserId, TenantId, Email) ->
    sign_access_token(UserId, TenantId, Email, <<"user">>).

%% Signs an access token with sub, tenant_id, email, role claims.
-spec sign_access_token(UserId :: binary(), TenantId :: binary(), Email :: binary(), Role :: binary()) ->
    {ok, Token :: binary()}.
sign_access_token(UserId, TenantId, Email, Role) ->
    Secret = get_secret(),
    TTL = application:get_env(aurix, jwt_access_ttl_sec, 900),
    Now = erlang:system_time(second),
    Claims = #{
        <<"sub">> => UserId,
        <<"tenant_id">> => TenantId,
        <<"email">> => Email,
        <<"role">> => Role,
        <<"iat">> => Now,
        <<"exp">> => Now + TTL
    },
    JWK = jose_jwk:from_oct(Secret),
    JWS = #{<<"alg">> => <<"HS256">>},
    Signed = jose_jwt:sign(JWK, JWS, Claims),
    {_JWSMap, Token} = jose_jws:compact(Signed),
    {ok, Token}.

%% Verifies and decodes a JWT token. Only accepts HS256 algorithm.
-spec verify_token(Token :: binary()) ->
    {ok, Claims :: map()} | {error, invalid_token | token_expired}.
verify_token(Token) ->
    Secret = get_secret(),
    JWK = jose_jwk:from_oct(Secret),
    try jose_jwt:verify_strict(JWK, [<<"HS256">>], Token) of
        {true, {jose_jwt, Claims}, _JWS} ->
            Now = erlang:system_time(second),
            Exp = maps:get(<<"exp">>, Claims, 0),
            case Exp > Now of
                true -> {ok, Claims};
                false -> {error, token_expired}
            end;
        {false, _JWT, _JWS} ->
            {error, invalid_token}
    catch
        _:_ -> {error, invalid_token}
    end.

%% Gets the JWT secret from application config.
-spec get_secret() -> binary().
get_secret() ->
    {ok, Secret} = application:get_env(aurix, jwt_secret),
    Secret.

-module(aurix_jwt_tests).
-include_lib("eunit/include/eunit.hrl").

%% Setup: mock app env
setup() ->
    application:set_env(aurix, jwt_secret, <<"test-secret-key-at-least-32-bytes!!">>),
    application:set_env(aurix, jwt_access_ttl_sec, 900).

sign_and_verify_test() ->
    setup(),
    UserId = <<"user-123">>,
    TenantId = <<"tenant-456">>,
    Email = <<"test@example.com">>,
    {ok, Token} = aurix_jwt:sign_access_token(UserId, TenantId, Email),
    ?assert(is_binary(Token)),
    {ok, Claims} = aurix_jwt:verify_token(Token),
    ?assertEqual(UserId, maps:get(<<"sub">>, Claims)),
    ?assertEqual(TenantId, maps:get(<<"tenant_id">>, Claims)),
    ?assertEqual(Email, maps:get(<<"email">>, Claims)).

verify_invalid_token_test() ->
    setup(),
    ?assertEqual({error, invalid_token}, aurix_jwt:verify_token(<<"garbage">>)).

verify_wrong_secret_test() ->
    setup(),
    {ok, Token} = aurix_jwt:sign_access_token(<<"u">>, <<"t">>, <<"e@e.com">>),
    application:set_env(aurix, jwt_secret, <<"different-secret-key-32-bytes!!!!!">>),
    ?assertEqual({error, invalid_token}, aurix_jwt:verify_token(Token)).

verify_expired_token_test() ->
    setup(),
    %% Set TTL to -1 to create an already-expired token
    application:set_env(aurix, jwt_access_ttl_sec, -1),
    {ok, Token} = aurix_jwt:sign_access_token(<<"u">>, <<"t">>, <<"e@e.com">>),
    application:set_env(aurix, jwt_access_ttl_sec, 900),
    ?assertEqual({error, token_expired}, aurix_jwt:verify_token(Token)).

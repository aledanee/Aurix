-module(auth_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([register_test/1, login_test/1, refresh_token_test/1,
         logout_test/1, change_password_test/1]).

all() ->
    [register_test, login_test, refresh_token_test,
     logout_test, change_password_test].

init_per_suite(Config) ->
    application:ensure_all_started(aurix),
    inets:start(),
    wait_for_http(),
    Config.

end_per_suite(_Config) ->
    ok.

%% -------------------------------------------------------------------
%% Test Cases
%% -------------------------------------------------------------------

register_test(_Config) ->
    Body = jsx:encode(#{
        <<"tenant_code">> => <<"aurix-demo">>,
        <<"email">> => unique_email(<<"reg">>),
        <<"password">> => <<"TestPassword123">>
    }),
    {ok, {{_, 201, _}, _Headers, RespBody}} = httpc:request(post,
        {"http://localhost:8080/auth/register", [], "application/json", Body}, [], []),
    Response = jsx:decode(list_to_binary(RespBody), [return_maps]),
    ?assert(maps:is_key(<<"user_id">>, Response)),
    ?assert(maps:is_key(<<"wallet_id">>, Response)).

login_test(_Config) ->
    Email = unique_email(<<"login">>),
    Password = <<"TestPassword123">>,
    register_user(<<"aurix-demo">>, Email, Password),
    LoginBody = jsx:encode(#{
        <<"tenant_code">> => <<"aurix-demo">>,
        <<"email">> => Email,
        <<"password">> => Password
    }),
    {ok, {{_, 200, _}, _, LoginResp}} = httpc:request(post,
        {"http://localhost:8080/auth/login", [], "application/json", LoginBody}, [], []),
    Tokens = jsx:decode(list_to_binary(LoginResp), [return_maps]),
    ?assert(maps:is_key(<<"access_token">>, Tokens)),
    ?assert(maps:is_key(<<"refresh_token">>, Tokens)).

refresh_token_test(_Config) ->
    {ok, Tokens} = register_and_login(<<"aurix-demo">>, unique_email(<<"refresh">>), <<"TestPassword123">>),
    RefreshToken = maps:get(<<"refresh_token">>, Tokens),
    RefreshBody = jsx:encode(#{<<"refresh_token">> => RefreshToken}),
    {ok, {{_, 200, _}, _, RefreshResp}} = httpc:request(post,
        {"http://localhost:8080/auth/refresh", [], "application/json", RefreshBody}, [], []),
    NewTokens = jsx:decode(list_to_binary(RefreshResp), [return_maps]),
    ?assert(maps:is_key(<<"access_token">>, NewTokens)),
    ?assert(maps:is_key(<<"refresh_token">>, NewTokens)).

logout_test(_Config) ->
    {ok, Tokens} = register_and_login(<<"aurix-demo">>, unique_email(<<"logout">>), <<"TestPassword123">>),
    AccessToken = maps:get(<<"access_token">>, Tokens),
    RefreshToken = maps:get(<<"refresh_token">>, Tokens),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(AccessToken)},
    LogoutBody = jsx:encode(#{<<"refresh_token">> => RefreshToken}),
    {ok, {{_, 200, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/logout", [AuthHeader], "application/json", LogoutBody}, [], []).

change_password_test(_Config) ->
    Email = unique_email(<<"chgpw">>),
    OldPassword = <<"TestPassword123">>,
    NewPassword = <<"NewPassword456">>,
    {ok, Tokens} = register_and_login(<<"aurix-demo">>, Email, OldPassword),
    AccessToken = maps:get(<<"access_token">>, Tokens),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(AccessToken)},
    ChgBody = jsx:encode(#{
        <<"current_password">> => OldPassword,
        <<"new_password">> => NewPassword
    }),
    {ok, {{_, 204, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/change-password", [AuthHeader], "application/json", ChgBody}, [], []),
    %% New password works
    LoginBody = jsx:encode(#{
        <<"tenant_code">> => <<"aurix-demo">>,
        <<"email">> => Email,
        <<"password">> => NewPassword
    }),
    {ok, {{_, 200, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/login", [], "application/json", LoginBody}, [], []).

%% -------------------------------------------------------------------
%% Helpers
%% -------------------------------------------------------------------

wait_for_http() ->
    wait_for_http(30).

wait_for_http(0) ->
    error(http_server_not_ready);
wait_for_http(N) ->
    case httpc:request(get, {"http://localhost:8080/health", []}, [{timeout, 1000}], []) of
        {ok, {{_, 200, _}, _, _}} -> ok;
        _ -> timer:sleep(500), wait_for_http(N - 1)
    end.

unique_email(Prefix) ->
    TS = integer_to_binary(erlang:system_time(microsecond)),
    <<Prefix/binary, "-", TS/binary, "@example.com">>.

register_user(TenantCode, Email, Password) ->
    RegBody = jsx:encode(#{
        <<"tenant_code">> => TenantCode,
        <<"email">> => Email,
        <<"password">> => Password
    }),
    {ok, {{_, 201, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/register", [], "application/json", RegBody}, [], []),
    ok.

register_and_login(TenantCode, Email, Password) ->
    register_user(TenantCode, Email, Password),
    LoginBody = jsx:encode(#{
        <<"tenant_code">> => TenantCode,
        <<"email">> => Email,
        <<"password">> => Password
    }),
    {ok, {{_, 200, _}, _, LoginResp}} = httpc:request(post,
        {"http://localhost:8080/auth/login", [], "application/json", LoginBody}, [], []),
    {ok, jsx:decode(list_to_binary(LoginResp), [return_maps])}.

-module(auth_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([register_test/1, register_duplicate_email_test/1,
         login_test/1, login_invalid_credentials_test/1,
         refresh_token_test/1, logout_test/1,
         change_password_test/1]).

all() ->
    [register_test, register_duplicate_email_test,
     login_test, login_invalid_credentials_test,
     refresh_token_test, logout_test,
     change_password_test].

init_per_suite(Config) ->
    %% Start the application and dependencies
    application:ensure_all_started(aurix),
    inets:start(),
    Config.

end_per_suite(_Config) ->
    ok.

register_test(_Config) ->
    %% POST /auth/register
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

register_duplicate_email_test(_Config) ->
    Email = unique_email(<<"dup">>),
    Body = jsx:encode(#{
        <<"tenant_code">> => <<"aurix-demo">>,
        <<"email">> => Email,
        <<"password">> => <<"TestPassword123">>
    }),
    %% First register succeeds
    {ok, {{_, 201, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/register", [], "application/json", Body}, [], []),
    %% Second register fails with 409
    {ok, {{_, 409, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/register", [], "application/json", Body}, [], []).

login_test(_Config) ->
    %% First register a user
    Email = unique_email(<<"login">>),
    Password = <<"TestPassword123">>,
    RegBody = jsx:encode(#{
        <<"tenant_code">> => <<"aurix-demo">>,
        <<"email">> => Email,
        <<"password">> => Password
    }),
    {ok, {{_, 201, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/register", [], "application/json", RegBody}, [], []),
    %% Now login
    LoginBody = jsx:encode(#{
        <<"tenant_code">> => <<"aurix-demo">>,
        <<"email">> => Email,
        <<"password">> => Password
    }),
    {ok, {{_, 200, _}, _, LoginResp}} = httpc:request(post,
        {"http://localhost:8080/auth/login", [], "application/json", LoginBody}, [], []),
    Tokens = jsx:decode(list_to_binary(LoginResp), [return_maps]),
    ?assert(maps:is_key(<<"access_token">>, Tokens)),
    ?assert(maps:is_key(<<"refresh_token">>, Tokens)),
    ?assertEqual(<<"Bearer">>, maps:get(<<"token_type">>, Tokens)).

login_invalid_credentials_test(_Config) ->
    Body = jsx:encode(#{
        <<"tenant_code">> => <<"aurix-demo">>,
        <<"email">> => <<"nonexistent@example.com">>,
        <<"password">> => <<"WrongPassword123">>
    }),
    {ok, {{_, 401, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/login", [], "application/json", Body}, [], []).

refresh_token_test(_Config) ->
    %% Register + login to get tokens
    Email = unique_email(<<"refresh">>),
    Password = <<"TestPassword123">>,
    {ok, Tokens} = register_and_login(<<"aurix-demo">>, Email, Password),
    RefreshToken = maps:get(<<"refresh_token">>, Tokens),
    %% POST /auth/refresh
    RefreshBody = jsx:encode(#{<<"refresh_token">> => RefreshToken}),
    {ok, {{_, 200, _}, _, RefreshResp}} = httpc:request(post,
        {"http://localhost:8080/auth/refresh", [], "application/json", RefreshBody}, [], []),
    NewTokens = jsx:decode(list_to_binary(RefreshResp), [return_maps]),
    ?assert(maps:is_key(<<"access_token">>, NewTokens)),
    ?assert(maps:is_key(<<"refresh_token">>, NewTokens)),
    %% Old refresh token should be rotated (using it again should fail)
    {ok, {{_, Code, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/refresh", [], "application/json", RefreshBody}, [], []),
    ?assert(Code >= 400).

logout_test(_Config) ->
    Email = unique_email(<<"logout">>),
    Password = <<"TestPassword123">>,
    {ok, Tokens} = register_and_login(<<"aurix-demo">>, Email, Password),
    AccessToken = maps:get(<<"access_token">>, Tokens),
    RefreshToken = maps:get(<<"refresh_token">>, Tokens),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(AccessToken)},
    LogoutBody = jsx:encode(#{<<"refresh_token">> => RefreshToken}),
    {ok, {{_, 200, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/logout", [AuthHeader], "application/json", LogoutBody}, [], []),
    %% Refresh token should no longer work
    RefreshBody = jsx:encode(#{<<"refresh_token">> => RefreshToken}),
    {ok, {{_, Code, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/refresh", [], "application/json", RefreshBody}, [], []),
    ?assert(Code >= 400).

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
    %% Old password should no longer work
    LoginBody = jsx:encode(#{
        <<"tenant_code">> => <<"aurix-demo">>,
        <<"email">> => Email,
        <<"password">> => OldPassword
    }),
    {ok, {{_, 401, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/login", [], "application/json", LoginBody}, [], []),
    %% New password should work
    LoginBody2 = jsx:encode(#{
        <<"tenant_code">> => <<"aurix-demo">>,
        <<"email">> => Email,
        <<"password">> => NewPassword
    }),
    {ok, {{_, 200, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/login", [], "application/json", LoginBody2}, [], []).

%% Helpers

unique_email(Prefix) ->
    TS = integer_to_binary(erlang:system_time(microsecond)),
    <<Prefix/binary, "-", TS/binary, "@example.com">>.

register_and_login(TenantCode, Email, Password) ->
    RegBody = jsx:encode(#{
        <<"tenant_code">> => TenantCode,
        <<"email">> => Email,
        <<"password">> => Password
    }),
    {ok, {{_, 201, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/register", [], "application/json", RegBody}, [], []),
    LoginBody = jsx:encode(#{
        <<"tenant_code">> => TenantCode,
        <<"email">> => Email,
        <<"password">> => Password
    }),
    {ok, {{_, 200, _}, _, LoginResp}} = httpc:request(post,
        {"http://localhost:8080/auth/login", [], "application/json", LoginBody}, [], []),
    {ok, jsx:decode(list_to_binary(LoginResp), [return_maps])}.

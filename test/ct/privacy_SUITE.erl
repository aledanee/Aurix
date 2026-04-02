-module(privacy_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([export_contains_profile_test/1, erasure_request_succeeds_test/1]).

all() ->
    [export_contains_profile_test, erasure_request_succeeds_test].

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

export_contains_profile_test(_Config) ->
    Email = unique_email(<<"priv-profile">>),
    {ok, Tokens} = register_and_login(<<"aurix-demo">>, Email, <<"TestPassword123">>),
    AccessToken = maps:get(<<"access_token">>, Tokens),
    AuthHeader = auth_header(AccessToken),

    {ok, {{_, 200, _}, _, RespBody}} = httpc:request(get,
        {"http://localhost:8080/privacy/export", [AuthHeader]}, [], []),
    Export = jsx:decode(list_to_binary(RespBody), [return_maps]),

    Profile = maps:get(<<"profile">>, Export),
    ?assert(maps:is_key(<<"email">>, Profile)),
    ?assertEqual(Email, maps:get(<<"email">>, Profile)).

erasure_request_succeeds_test(_Config) ->
    Email = unique_email(<<"priv-erase">>),
    {ok, Tokens} = register_and_login(<<"aurix-demo">>, Email, <<"TestPassword123">>),
    AccessToken = maps:get(<<"access_token">>, Tokens),
    AuthHeader = auth_header(AccessToken),

    {ok, {{_, Status, _}, _, RespBody}} = httpc:request(post,
        {"http://localhost:8080/privacy/erasure-request", [AuthHeader], "application/json", <<>>}, [], []),
    ?assert(Status =:= 200 orelse Status =:= 202),
    Response = jsx:decode(list_to_binary(RespBody), [return_maps]),
    ?assertEqual(<<"accepted">>, maps:get(<<"status">>, Response)).

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

auth_header(AccessToken) ->
    {"Authorization", "Bearer " ++ binary_to_list(AccessToken)}.

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

-module(admin_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([list_tenants_test/1, deactivate_tenant_test/1,
         update_gold_price_test/1, update_fee_config_test/1,
         trigger_etl_test/1]).

all() ->
    [list_tenants_test, deactivate_tenant_test,
     update_gold_price_test, update_fee_config_test,
     trigger_etl_test].

init_per_suite(Config) ->
    application:ensure_all_started(aurix),
    inets:start(),
    wait_for_http(),

    TenantCode = <<"aurix-demo">>,
    TenantId = <<"a0000000-0000-0000-0000-000000000001">>,
    Password = <<"TestPassword123">>,

    %% Register and promote an admin user
    AdminEmail = unique_email(<<"admin">>),
    {ok, _} = register_and_login(TenantCode, AdminEmail, Password),
    {ok, _, _} = pgapp:equery(
        "UPDATE users SET role = 'admin' WHERE email = $1 AND tenant_id = $2",
        [AdminEmail, TenantId]),
    %% Login again to get a JWT with the admin role
    AdminTokens = login(TenantCode, AdminEmail, Password),
    AdminToken = maps:get(<<"access_token">>, AdminTokens),

    [{admin_token, AdminToken},
     {tenant_id, TenantId} | Config].

end_per_suite(_Config) ->
    ok.

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(deactivate_tenant_test, _Config) ->
    %% Re-activate the partner-co tenant
    pgapp:equery(
        "UPDATE tenants SET status = 'active' WHERE id = $1",
        [<<"b0000000-0000-0000-0000-000000000002">>]),
    ok;
end_per_testcase(update_gold_price_test, Config) ->
    %% Reset gold price to original 65.00
    Token = proplists:get_value(admin_token, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    Body = jsx:encode(#{<<"price_eur">> => <<"65.00">>}),
    httpc:request(post,
        {"http://localhost:8080/admin/gold-price", [AuthHeader], "application/json", Body}, [], []),
    ok;
end_per_testcase(update_fee_config_test, Config) ->
    %% Reset fee config to original values
    Token = proplists:get_value(admin_token, Config),
    TenantId = proplists:get_value(tenant_id, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    Body = jsx:encode(#{
        <<"buy_fee_rate">> => <<"0.005000">>,
        <<"sell_fee_rate">> => <<"0.005000">>,
        <<"min_fee_eur_cents">> => 50
    }),
    Url = "http://localhost:8080/admin/tenants/" ++ binary_to_list(TenantId) ++ "/fees",
    httpc:request(put, {Url, [AuthHeader], "application/json", Body}, [], []),
    ok;
end_per_testcase(_TestCase, _Config) ->
    ok.

%% -------------------------------------------------------------------
%% Test Cases
%% -------------------------------------------------------------------

list_tenants_test(Config) ->
    Token = proplists:get_value(admin_token, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    {ok, {{_, 200, _}, _, RespBody}} = httpc:request(get,
        {"http://localhost:8080/admin/tenants", [AuthHeader]}, [], []),
    Response = jsx:decode(list_to_binary(RespBody), [return_maps]),
    ?assert(maps:is_key(<<"items">>, Response)),
    Items = maps:get(<<"items">>, Response),
    ?assert(length(Items) >= 2).

deactivate_tenant_test(Config) ->
    Token = proplists:get_value(admin_token, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    TargetTenant = "b0000000-0000-0000-0000-000000000002",
    {ok, {{_, 200, _}, _, RespBody}} = httpc:request(post,
        {"http://localhost:8080/admin/tenants/" ++ TargetTenant ++ "/deactivate",
         [AuthHeader], "application/json", <<>>}, [], []),
    Response = jsx:decode(list_to_binary(RespBody), [return_maps]),
    ?assertEqual(<<"deactivated">>, maps:get(<<"status">>, Response)).

update_gold_price_test(Config) ->
    Token = proplists:get_value(admin_token, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    Body = jsx:encode(#{<<"price_eur">> => <<"72.50">>}),
    {ok, {{_, 200, _}, _, RespBody}} = httpc:request(post,
        {"http://localhost:8080/admin/gold-price", [AuthHeader], "application/json", Body}, [], []),
    Response = jsx:decode(list_to_binary(RespBody), [return_maps]),
    ?assertEqual(<<"updated">>, maps:get(<<"status">>, Response)).

update_fee_config_test(Config) ->
    Token = proplists:get_value(admin_token, Config),
    TenantId = proplists:get_value(tenant_id, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    Body = jsx:encode(#{
        <<"buy_fee_rate">> => <<"0.010000">>,
        <<"sell_fee_rate">> => <<"0.008000">>,
        <<"min_fee_eur_cents">> => 100
    }),
    Url = "http://localhost:8080/admin/tenants/" ++ binary_to_list(TenantId) ++ "/fees",
    {ok, {{_, 200, _}, _, RespBody}} = httpc:request(put,
        {Url, [AuthHeader], "application/json", Body}, [], []),
    Response = jsx:decode(list_to_binary(RespBody), [return_maps]),
    ?assertEqual(<<"updated">>, maps:get(<<"status">>, Response)).

trigger_etl_test(Config) ->
    Token = proplists:get_value(admin_token, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    {ok, {{_, 200, _}, _, RespBody}} = httpc:request(post,
        {"http://localhost:8080/admin/etl/trigger", [AuthHeader], "application/json", <<>>}, [], []),
    Response = jsx:decode(list_to_binary(RespBody), [return_maps]),
    ?assertEqual(<<"triggered">>, maps:get(<<"status">>, Response)).

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

login(TenantCode, Email, Password) ->
    LoginBody = jsx:encode(#{
        <<"tenant_code">> => TenantCode,
        <<"email">> => Email,
        <<"password">> => Password
    }),
    {ok, {{_, 200, _}, _, LoginResp}} = httpc:request(post,
        {"http://localhost:8080/auth/login", [], "application/json", LoginBody}, [], []),
    jsx:decode(list_to_binary(LoginResp), [return_maps]).

-module(wallet_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([view_wallet_test/1, buy_gold_test/1, sell_gold_test/1]).

all() ->
    [view_wallet_test, buy_gold_test, sell_gold_test].

init_per_suite(Config) ->
    application:ensure_all_started(aurix),
    inets:start(),
    wait_for_http(),
    %% Register and login a test user
    Email = unique_email(<<"wallet">>),
    Password = <<"TestPassword123">>,
    {ok, Tokens} = register_and_login(<<"aurix-demo">>, Email, Password),
    AccessToken = maps:get(<<"access_token">>, Tokens),
    [{access_token, AccessToken} | Config].

end_per_suite(_Config) ->
    ok.

%% -------------------------------------------------------------------
%% Test Cases
%% -------------------------------------------------------------------

view_wallet_test(Config) ->
    Token = proplists:get_value(access_token, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    {ok, {{_, 200, _}, _, Body}} = httpc:request(get,
        {"http://localhost:8080/wallet", [AuthHeader]}, [], []),
    Wallet = jsx:decode(list_to_binary(Body), [return_maps]),
    ?assert(maps:is_key(<<"wallet_id">>, Wallet)),
    ?assert(maps:is_key(<<"gold_balance_grams">>, Wallet)),
    ?assert(maps:is_key(<<"fiat_balance_eur">>, Wallet)).

buy_gold_test(Config) ->
    Token = proplists:get_value(access_token, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    IdempKey = idemp_key(),
    BuyBody = jsx:encode(#{<<"grams">> => <<"1.00000000">>}),
    {ok, {{_, 200, _}, _, Body}} = httpc:request(post,
        {"http://localhost:8080/wallet/buy", [AuthHeader, IdempKey], "application/json", BuyBody}, [], []),
    Result = jsx:decode(list_to_binary(Body), [return_maps]),
    Txn = maps:get(<<"transaction">>, Result),
    ?assertEqual(<<"buy">>, maps:get(<<"type">>, Txn)).

sell_gold_test(Config) ->
    Token = proplists:get_value(access_token, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    %% First buy some gold to have a balance
    BuyKey = idemp_key(),
    BuyBody = jsx:encode(#{<<"grams">> => <<"2.00000000">>}),
    {ok, {{_, 200, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/wallet/buy", [AuthHeader, BuyKey], "application/json", BuyBody}, [], []),
    %% Then sell
    SellKey = idemp_key(),
    SellBody = jsx:encode(#{<<"grams">> => <<"0.50000000">>}),
    {ok, {{_, 200, _}, _, Body}} = httpc:request(post,
        {"http://localhost:8080/wallet/sell", [AuthHeader, SellKey], "application/json", SellBody}, [], []),
    Result = jsx:decode(list_to_binary(Body), [return_maps]),
    Txn = maps:get(<<"transaction">>, Result),
    ?assertEqual(<<"sell">>, maps:get(<<"type">>, Txn)).

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

idemp_key() ->
    {"Idempotency-Key", "test-" ++ integer_to_list(erlang:system_time(microsecond))}.

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

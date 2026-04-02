-module(wallet_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1, init_per_testcase/2, end_per_testcase/2]).
-export([view_wallet_test/1, buy_gold_test/1, sell_gold_test/1,
         buy_insufficient_balance_test/1, sell_insufficient_gold_test/1,
         idempotency_test/1]).

all() ->
    [view_wallet_test, buy_gold_test, sell_gold_test,
     buy_insufficient_balance_test, sell_insufficient_gold_test,
     idempotency_test].

init_per_suite(Config) ->
    application:ensure_all_started(aurix),
    inets:start(),
    %% Register and login a test user
    Email = <<"wallet-", (integer_to_binary(erlang:system_time(microsecond)))/binary, "@example.com">>,
    Password = <<"TestPassword123">>,

    RegBody = jsx:encode(#{
        <<"tenant_code">> => <<"aurix-demo">>,
        <<"email">> => Email,
        <<"password">> => Password
    }),
    {ok, {{_, 201, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/auth/register", [], "application/json", RegBody}, [], []),

    LoginBody = jsx:encode(#{
        <<"tenant_code">> => <<"aurix-demo">>,
        <<"email">> => Email,
        <<"password">> => Password
    }),
    {ok, {{_, 200, _}, _, LoginResp}} = httpc:request(post,
        {"http://localhost:8080/auth/login", [], "application/json", LoginBody}, [], []),
    Tokens = jsx:decode(list_to_binary(LoginResp), [return_maps]),
    AccessToken = maps:get(<<"access_token">>, Tokens),
    [{access_token, AccessToken} | Config].

end_per_suite(_Config) ->
    ok.

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, _Config) ->
    ok.

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
    IdempKey = {"Idempotency-Key", "buy-test-" ++ integer_to_list(erlang:system_time(microsecond))},
    BuyBody = jsx:encode(#{<<"grams">> => <<"1.00000000">>}),
    {ok, {{_, 200, _}, _, Body}} = httpc:request(post,
        {"http://localhost:8080/wallet/buy", [AuthHeader, IdempKey], "application/json", BuyBody}, [], []),
    Result = jsx:decode(list_to_binary(Body), [return_maps]),
    ?assert(maps:is_key(<<"transaction">>, Result)),
    ?assert(maps:is_key(<<"wallet">>, Result)),
    Txn = maps:get(<<"transaction">>, Result),
    ?assertEqual(<<"buy">>, maps:get(<<"type">>, Txn)).

sell_gold_test(Config) ->
    Token = proplists:get_value(access_token, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    %% First buy some gold
    BuyKey = {"Idempotency-Key", "pre-sell-buy-" ++ integer_to_list(erlang:system_time(microsecond))},
    BuyBody = jsx:encode(#{<<"grams">> => <<"2.00000000">>}),
    {ok, {{_, 200, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/wallet/buy", [AuthHeader, BuyKey], "application/json", BuyBody}, [], []),
    %% Then sell
    SellKey = {"Idempotency-Key", "sell-test-" ++ integer_to_list(erlang:system_time(microsecond))},
    SellBody = jsx:encode(#{<<"grams">> => <<"0.50000000">>}),
    {ok, {{_, 200, _}, _, Body}} = httpc:request(post,
        {"http://localhost:8080/wallet/sell", [AuthHeader, SellKey], "application/json", SellBody}, [], []),
    Result = jsx:decode(list_to_binary(Body), [return_maps]),
    Txn = maps:get(<<"transaction">>, Result),
    ?assertEqual(<<"sell">>, maps:get(<<"type">>, Txn)).

buy_insufficient_balance_test(Config) ->
    Token = proplists:get_value(access_token, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    IdempKey = {"Idempotency-Key", "insuf-" ++ integer_to_list(erlang:system_time(microsecond))},
    %% Try to buy way more gold than balance allows (99999 grams at ~65 EUR each = way over 10K EUR)
    BuyBody = jsx:encode(#{<<"grams">> => <<"99999.00000000">>}),
    {ok, {{_, 422, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/wallet/buy", [AuthHeader, IdempKey], "application/json", BuyBody}, [], []).

sell_insufficient_gold_test(Config) ->
    Token = proplists:get_value(access_token, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    IdempKey = {"Idempotency-Key", "insuf-gold-" ++ integer_to_list(erlang:system_time(microsecond))},
    SellBody = jsx:encode(#{<<"grams">> => <<"99999.00000000">>}),
    {ok, {{_, 422, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/wallet/sell", [AuthHeader, IdempKey], "application/json", SellBody}, [], []).

idempotency_test(Config) ->
    Token = proplists:get_value(access_token, Config),
    AuthHeader = {"Authorization", "Bearer " ++ binary_to_list(Token)},
    IdempKey = {"Idempotency-Key", "idemp-" ++ integer_to_list(erlang:system_time(microsecond))},
    BuyBody = jsx:encode(#{<<"grams">> => <<"0.10000000">>}),
    %% First request succeeds
    {ok, {{_, 200, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/wallet/buy", [AuthHeader, IdempKey], "application/json", BuyBody}, [], []),
    %% Duplicate returns 409
    {ok, {{_, 409, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/wallet/buy", [AuthHeader, IdempKey], "application/json", BuyBody}, [], []).

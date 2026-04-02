-module(tenant_isolation_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([wallet_isolation_test/1, transaction_isolation_test/1]).

all() ->
    [wallet_isolation_test, transaction_isolation_test].

init_per_suite(Config) ->
    application:ensure_all_started(aurix),
    inets:start(),

    %% Ensure partner-co tenant has a fee config so buy operations work.
    %% The seed data only creates fee config for aurix-demo.
    ensure_partner_fee_config(),

    %% Register user in tenant A (aurix-demo)
    EmailA = <<"iso-a-", (integer_to_binary(erlang:system_time(microsecond)))/binary, "@example.com">>,
    {ok, TokenA} = register_and_login(<<"aurix-demo">>, EmailA, <<"TestPassword123">>),

    %% Register user in tenant B (partner-co)
    EmailB = <<"iso-b-", (integer_to_binary(erlang:system_time(microsecond)))/binary, "@example.com">>,
    {ok, TokenB} = register_and_login(<<"partner-co">>, EmailB, <<"TestPassword123">>),

    %% Buy some gold as user A
    AuthA = {"Authorization", "Bearer " ++ binary_to_list(TokenA)},
    BuyKey = {"Idempotency-Key", "iso-buy-" ++ integer_to_list(erlang:system_time(microsecond))},
    BuyBody = jsx:encode(#{<<"grams">> => <<"1.00000000">>}),
    {ok, {{_, 200, _}, _, _}} = httpc:request(post,
        {"http://localhost:8080/wallet/buy", [AuthA, BuyKey], "application/json", BuyBody}, [], []),

    [{token_a, TokenA}, {token_b, TokenB} | Config].

end_per_suite(_Config) ->
    ok.

wallet_isolation_test(Config) ->
    TokenA = proplists:get_value(token_a, Config),
    TokenB = proplists:get_value(token_b, Config),

    %% Get wallet A
    AuthA = {"Authorization", "Bearer " ++ binary_to_list(TokenA)},
    {ok, {{_, 200, _}, _, BodyA}} = httpc:request(get,
        {"http://localhost:8080/wallet", [AuthA]}, [], []),
    WalletA = jsx:decode(list_to_binary(BodyA), [return_maps]),

    %% Get wallet B
    AuthB = {"Authorization", "Bearer " ++ binary_to_list(TokenB)},
    {ok, {{_, 200, _}, _, BodyB}} = httpc:request(get,
        {"http://localhost:8080/wallet", [AuthB]}, [], []),
    WalletB = jsx:decode(list_to_binary(BodyB), [return_maps]),

    %% User A bought gold, gold balance should be > 0
    %% User B didn't buy gold, gold balance should be "0.00000000"
    ?assertNotEqual(maps:get(<<"gold_balance_grams">>, WalletA),
                    maps:get(<<"gold_balance_grams">>, WalletB)),
    %% Different wallet IDs
    ?assertNotEqual(maps:get(<<"wallet_id">>, WalletA),
                    maps:get(<<"wallet_id">>, WalletB)).

transaction_isolation_test(Config) ->
    TokenB = proplists:get_value(token_b, Config),

    %% User B should see NO transactions (they didn't trade)
    AuthB = {"Authorization", "Bearer " ++ binary_to_list(TokenB)},
    {ok, {{_, 200, _}, _, Body}} = httpc:request(get,
        {"http://localhost:8080/transactions", [AuthB]}, [], []),
    Result = jsx:decode(list_to_binary(Body), [return_maps]),
    Items = maps:get(<<"items">>, Result),
    ?assertEqual([], Items).

%% Helpers

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
    Tokens = jsx:decode(list_to_binary(LoginResp), [return_maps]),
    {ok, maps:get(<<"access_token">>, Tokens)}.

%% Insert fee config for partner-co if it doesn't exist.
%% partner-co tenant_id = b0000000-0000-0000-0000-000000000002
ensure_partner_fee_config() ->
    TenantId = <<"b0000000-0000-0000-0000-000000000002">>,
    FeeId = <<"d0000000-0000-0000-0000-000000000001">>,
    SQL = "INSERT INTO tenant_fee_config (id, tenant_id, buy_fee_rate, sell_fee_rate, min_fee_eur_cents) "
          "VALUES ($1, $2, 0.005000, 0.005000, 50) "
          "ON CONFLICT (tenant_id) DO NOTHING",
    aurix_db:query(SQL, [FeeId, TenantId]),
    ok.

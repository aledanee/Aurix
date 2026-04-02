-module(aurix_wallet_service).

-export([view/2, buy/4, sell/4]).

%%====================================================================
%% API
%%====================================================================

%% US-2.1 View wallet balance.
-spec view(TenantId :: binary(), UserId :: binary()) ->
    {ok, map()} | {error, not_found}.
view(TenantId, UserId) ->
    aurix_repo_wallet:get_by_user_id(TenantId, UserId).

%% US-2.2 Buy gold: debit fiat, credit gold.
-spec buy(TenantId :: binary(), UserId :: binary(),
          Grams :: binary(), IdempotencyKey :: binary()) ->
    {ok, map()} | {ok, duplicate, map()} | {error, term()}.
buy(TenantId, UserId, Grams, IdempotencyKey) ->
    case aurix_repo_transaction:check_idempotency(TenantId, IdempotencyKey) of
        {ok, ExistingTxn} ->
            {ok, duplicate, ExistingTxn};
        {error, not_found} ->
            execute_buy(TenantId, UserId, Grams, IdempotencyKey)
    end.

%% US-2.3 Sell gold: debit gold, credit fiat.
-spec sell(TenantId :: binary(), UserId :: binary(),
           Grams :: binary(), IdempotencyKey :: binary()) ->
    {ok, map()} | {ok, duplicate, map()} | {error, term()}.
sell(TenantId, UserId, Grams, IdempotencyKey) ->
    case aurix_repo_transaction:check_idempotency(TenantId, IdempotencyKey) of
        {ok, ExistingTxn} ->
            {ok, duplicate, ExistingTxn};
        {error, not_found} ->
            execute_sell(TenantId, UserId, Grams, IdempotencyKey)
    end.

%%====================================================================
%% Internal — Buy
%%====================================================================

execute_buy(TenantId, UserId, Grams, IdempotencyKey) ->
    GramsFloat = parse_decimal(Grams),
    case GramsFloat > 0 of
        false ->
            {error, invalid_amount};
        true ->
            {ok, PriceCents} = aurix_price_provider:get_price(),
            {ok, FeeConfig} = aurix_repo_fee_config:get_by_tenant_id(TenantId),

            GrossEurCents = round(GramsFloat * PriceCents),
            BuyFeeRate = parse_decimal(maps:get(buy_fee_rate, FeeConfig)),
            MinFeeCents = maps:get(min_fee_eur_cents, FeeConfig),
            FeeEurCents = max(MinFeeCents, round(GrossEurCents * BuyFeeRate)),
            TotalEurCents = GrossEurCents + FeeEurCents,

            TxnId = generate_uuid(),
            %% Format price as precise decimal string for PostgreSQL numeric(24,8)
            PricePerGram = format_price_decimal(PriceCents),

            aurix_db:transaction(fun(Conn) ->
                case lock_wallet(Conn, TenantId, UserId) of
                    {error, _} = Err ->
                        Err;
                    {ok, Wallet} ->
                        #{id := WalletId,
                          fiat_balance_eur_cents := FiatBal,
                          version := Version} = Wallet,
                        case FiatBal >= TotalEurCents of
                            false ->
                                {error, insufficient_balance};
                            true ->
                                update_wallet_buy(Conn, TenantId, UserId,
                                                  TotalEurCents, GramsFloat, Version),
                                insert_ledger_entry(Conn, TxnId, TenantId, WalletId,
                                                    UserId, <<"buy">>, GramsFloat,
                                                    PricePerGram, GrossEurCents,
                                                    FeeEurCents, IdempotencyKey),
                                insert_outbox_event(Conn, TenantId, WalletId,
                                                    <<"wallet.buy.posted">>, TxnId,
                                                    UserId, <<"buy">>, GramsFloat,
                                                    PricePerGram, GrossEurCents, FeeEurCents),
                                %% Re-read wallet for PostgreSQL-computed balances
                                %% instead of computing in Erlang with floats.
                                {ok, UpdatedWallet} = read_wallet(Conn, TenantId, UserId),
                                {ok, #{
                                    transaction => #{
                                        id => TxnId,
                                        type => <<"buy">>,
                                        gold_grams => Grams,
                                        price_eur_per_gram => PricePerGram,
                                        gross_eur_cents => GrossEurCents,
                                        fee_eur_cents => FeeEurCents
                                    },
                                    wallet => #{
                                        gold_balance_grams => maps:get(gold_balance_grams, UpdatedWallet),
                                        fiat_balance_eur_cents => maps:get(fiat_balance_eur_cents, UpdatedWallet)
                                    }
                                }}
                        end
                end
            end)
    end.

%%====================================================================
%% Internal — Sell
%%====================================================================

execute_sell(TenantId, UserId, Grams, IdempotencyKey) ->
    GramsFloat = parse_decimal(Grams),
    case GramsFloat > 0 of
        false ->
            {error, invalid_amount};
        true ->
            {ok, PriceCents} = aurix_price_provider:get_price(),
            {ok, FeeConfig} = aurix_repo_fee_config:get_by_tenant_id(TenantId),

            GrossEurCents = round(GramsFloat * PriceCents),
            SellFeeRate = parse_decimal(maps:get(sell_fee_rate, FeeConfig)),
            MinFeeCents = maps:get(min_fee_eur_cents, FeeConfig),
            FeeEurCents = max(MinFeeCents, round(GrossEurCents * SellFeeRate)),
            NetEurCents = GrossEurCents - FeeEurCents,

            TxnId = generate_uuid(),
            %% Format price as precise decimal string for PostgreSQL numeric(24,8)
            PricePerGram = format_price_decimal(PriceCents),

            aurix_db:transaction(fun(Conn) ->
                case lock_wallet(Conn, TenantId, UserId) of
                    {error, _} = Err ->
                        Err;
                    {ok, Wallet} ->
                        #{id := WalletId,
                          gold_balance_grams := GoldBal,
                          version := Version} = Wallet,
                        %% Pre-check: float comparison is acceptable here as a
                        %% guard; the real enforcement is PostgreSQL numeric precision.
                        GoldBalFloat = parse_decimal(GoldBal),
                        case GramsFloat =< GoldBalFloat of
                            false ->
                                {error, insufficient_gold};
                            true ->
                                update_wallet_sell(Conn, TenantId, UserId,
                                                   GramsFloat, NetEurCents, Version),
                                insert_ledger_entry(Conn, TxnId, TenantId, WalletId,
                                                    UserId, <<"sell">>, GramsFloat,
                                                    PricePerGram, GrossEurCents,
                                                    FeeEurCents, IdempotencyKey),
                                insert_outbox_event(Conn, TenantId, WalletId,
                                                    <<"wallet.sell.posted">>, TxnId,
                                                    UserId, <<"sell">>, GramsFloat,
                                                    PricePerGram, GrossEurCents, FeeEurCents),
                                %% Re-read wallet for PostgreSQL-computed balances
                                %% instead of computing in Erlang with floats.
                                {ok, UpdatedWallet} = read_wallet(Conn, TenantId, UserId),
                                {ok, #{
                                    transaction => #{
                                        id => TxnId,
                                        type => <<"sell">>,
                                        gold_grams => Grams,
                                        price_eur_per_gram => PricePerGram,
                                        gross_eur_cents => GrossEurCents,
                                        fee_eur_cents => FeeEurCents
                                    },
                                    wallet => #{
                                        gold_balance_grams => maps:get(gold_balance_grams, UpdatedWallet),
                                        fiat_balance_eur_cents => maps:get(fiat_balance_eur_cents, UpdatedWallet)
                                    }
                                }}
                        end
                end
            end)
    end.

%%====================================================================
%% Internal — DB Operations (within transaction)
%%====================================================================

read_wallet(Conn, TenantId, UserId) ->
    SQL = "SELECT gold_balance_grams, fiat_balance_eur_cents "
          "FROM wallets WHERE tenant_id = $1 AND user_id = $2",
    case aurix_db:equery(Conn, SQL, [TenantId, UserId]) of
        {ok, _Cols, [{GoldBal, FiatBal}]} ->
            {ok, #{gold_balance_grams => GoldBal, fiat_balance_eur_cents => FiatBal}};
        {ok, _Cols, []} ->
            {error, wallet_not_found}
    end.

lock_wallet(Conn, TenantId, UserId) ->
    SQL = "SELECT id, gold_balance_grams, fiat_balance_eur_cents, version "
          "FROM wallets WHERE tenant_id = $1 AND user_id = $2 FOR UPDATE",
    case aurix_db:equery(Conn, SQL, [TenantId, UserId]) of
        {ok, _Cols, [{WalletId, GoldBal, FiatBal, Version}]} ->
            {ok, #{id => WalletId,
                   gold_balance_grams => GoldBal,
                   fiat_balance_eur_cents => FiatBal,
                   version => Version}};
        {ok, _Cols, []} ->
            {error, wallet_not_found}
    end.

update_wallet_buy(Conn, TenantId, UserId, TotalEurCents, GramsFloat, Version) ->
    SQL = "UPDATE wallets SET "
          "fiat_balance_eur_cents = fiat_balance_eur_cents - $3, "
          "gold_balance_grams = gold_balance_grams + $4, "
          "version = version + 1, updated_at = now() "
          "WHERE tenant_id = $1 AND user_id = $2 AND version = $5",
    case aurix_db:equery(Conn, SQL, [TenantId, UserId, TotalEurCents, GramsFloat, Version]) of
        {ok, 1} -> ok;
        {ok, 0} -> error(version_conflict)
    end.

update_wallet_sell(Conn, TenantId, UserId, GramsFloat, NetEurCents, Version) ->
    SQL = "UPDATE wallets SET "
          "gold_balance_grams = gold_balance_grams - $3, "
          "fiat_balance_eur_cents = fiat_balance_eur_cents + $4, "
          "version = version + 1, updated_at = now() "
          "WHERE tenant_id = $1 AND user_id = $2 AND version = $5",
    case aurix_db:equery(Conn, SQL, [TenantId, UserId, GramsFloat, NetEurCents, Version]) of
        {ok, 1} -> ok;
        {ok, 0} -> error(version_conflict)
    end.

insert_ledger_entry(Conn, TxnId, TenantId, WalletId, UserId, Type,
                    GramsFloat, PricePerGram, GrossEurCents, FeeEurCents,
                    IdempotencyKey) ->
    {ok, _} = aurix_repo_transaction:insert(Conn, #{
        id => TxnId,
        tenant_id => TenantId,
        wallet_id => WalletId,
        user_id => UserId,
        type => Type,
        gold_grams => GramsFloat,
        price_eur_per_gram => PricePerGram,
        gross_eur_cents => GrossEurCents,
        fee_eur_cents => FeeEurCents,
        idempotency_key => IdempotencyKey
    }).

insert_outbox_event(Conn, TenantId, WalletId, EventType, TxnId,
                    UserId, Type, GramsFloat, PricePerGram, GrossEurCents, FeeEurCents) ->
    ok = aurix_repo_outbox:insert(Conn, #{
        tenant_id => TenantId,
        aggregate_type => <<"wallet">>,
        aggregate_id => WalletId,
        event_type => EventType,
        payload => #{
            <<"transaction_id">> => TxnId,
            <<"user_id">> => UserId,
            <<"type">> => Type,
            <<"gold_grams">> => GramsFloat,
            <<"price_eur_per_gram">> => PricePerGram,
            <<"gross_eur_cents">> => GrossEurCents,
            <<"fee_eur_cents">> => FeeEurCents,
            <<"timestamp">> => iso8601_now()
        }
    }).

%%====================================================================
%% Internal — Helpers
%%====================================================================

-spec parse_decimal(binary() | float() | integer()) -> float().
parse_decimal(V) when is_float(V) -> V;
parse_decimal(V) when is_integer(V) -> V * 1.0;
parse_decimal(V) when is_binary(V) ->
    case binary:match(V, <<".">>) of
        nomatch -> float(binary_to_integer(V));
        _ -> binary_to_float(V)
    end.

-spec format_price_decimal(PriceCents :: integer()) -> binary().
format_price_decimal(PriceCents) when is_integer(PriceCents) ->
    Whole = PriceCents div 100,
    Frac = PriceCents rem 100,
    iolist_to_binary(io_lib:format("~B.~2..0B000000", [Whole, Frac])).

-spec iso8601_now() -> binary().
iso8601_now() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:universal_time(),
    iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
                                    [Y, Mo, D, H, Mi, S])).

-spec generate_uuid() -> binary().
generate_uuid() ->
    uuid:uuid_to_string(uuid:get_v4_urandom(), binary_standard).

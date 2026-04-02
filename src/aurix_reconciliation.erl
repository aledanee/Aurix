-module(aurix_reconciliation).
-behaviour(gen_server).

-export([start_link/0, run_now/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(RECONCILE_INTERVAL_MS, 21600000). %% 6 hours

-record(state, {}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Manual trigger
-spec run_now() -> ok.
run_now() ->
    gen_server:cast(?MODULE, run_now).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    schedule_reconciliation(),
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(run_now, State) ->
    run_reconciliation(),
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(reconcile, State) ->
    run_reconciliation(),
    schedule_reconciliation(),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% internal
%%====================================================================

schedule_reconciliation() ->
    erlang:send_after(?RECONCILE_INTERVAL_MS, self(), reconcile).

run_reconciliation() ->
    logger:info(#{action => <<"reconciliation.start">>}),
    SQL = "SELECT w.id, w.tenant_id, w.user_id, w.gold_balance_grams, w.fiat_balance_eur_cents, "
          "COALESCE(SUM(CASE WHEN t.type = 'buy' THEN t.gold_grams ELSE 0 END), 0) as bought_gold, "
          "COALESCE(SUM(CASE WHEN t.type = 'sell' THEN t.gold_grams ELSE 0 END), 0) as sold_gold, "
          "COALESCE(SUM(CASE WHEN t.type = 'buy' THEN -(t.gross_eur_cents + t.fee_eur_cents) "
          "                   WHEN t.type = 'sell' THEN (t.gross_eur_cents - t.fee_eur_cents) "
          "                   ELSE 0 END), 0) as net_fiat_cents "
          "FROM wallets w "
          "LEFT JOIN transactions t ON t.wallet_id = w.id AND t.tenant_id = w.tenant_id AND t.status = 'posted' "
          "GROUP BY w.id, w.tenant_id, w.user_id, w.gold_balance_grams, w.fiat_balance_eur_cents",
    case pgapp:equery(SQL, []) of
        {ok, _, Rows} ->
            Mismatches = check_rows(Rows),
            case Mismatches of
                0 -> logger:info(#{action => <<"reconciliation.complete">>, wallet_count => length(Rows), mismatches => 0});
                N -> logger:warning(#{action => <<"reconciliation.complete">>, wallet_count => length(Rows), mismatches => N})
            end;
        {error, Reason} ->
            logger:error(#{action => <<"reconciliation.error">>, reason => Reason})
    end.

check_rows(Rows) ->
    lists:foldl(fun(Row, MismatchCount) ->
        {WalletId, TenantId, _UserId, StoredGold, StoredFiat,
         BoughtGold, SoldGold, NetFiatCents} = Row,
        %% Expected gold = bought - sold (starting from 0)
        ExpectedGold = to_number(BoughtGold) - to_number(SoldGold),
        %% Expected fiat = initial_balance + net_fiat_cents
        InitialFiat = get_seed_balance(),
        ExpectedFiat = InitialFiat + NetFiatCents,
        StoredGoldNum = to_number(StoredGold),
        GoldMatch = abs(StoredGoldNum - ExpectedGold) < 0.00000001,
        FiatMatch = StoredFiat =:= ExpectedFiat,
        case GoldMatch andalso FiatMatch of
            true -> MismatchCount;
            false ->
                logger:warning(#{action => <<"reconciliation.mismatch">>, wallet_id => WalletId, tenant_id => TenantId, stored_gold => StoredGoldNum, expected_gold => ExpectedGold, stored_fiat => StoredFiat, expected_fiat => ExpectedFiat}),
                MismatchCount + 1
        end
    end, 0, Rows).

get_seed_balance() ->
    application:get_env(aurix, seed_fiat_balance_cents, 1000000).

%%====================================================================
%% Utility helpers
%%====================================================================

to_number(V) when is_integer(V) -> V;
to_number(V) when is_float(V) -> V;
to_number(V) when is_binary(V) ->
    case binary:match(V, <<".">>) of
        nomatch -> binary_to_integer(V);
        _ -> binary_to_float(V)
    end.

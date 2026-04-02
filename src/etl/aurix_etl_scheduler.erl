-module(aurix_etl_scheduler).
-behaviour(gen_server).

-export([start_link/0, run_now/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(ETL_INTERVAL_MS, 3600000). %% 1 hour

-record(state, {}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec run_now() -> ok.
run_now() ->
    gen_server:cast(?MODULE, run_now).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    schedule_etl(),
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(run_now, State) ->
    NewState = run_etl_job(State),
    {noreply, NewState};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(run_etl, State) ->
    NewState = run_etl_job(State),
    schedule_etl(),
    {noreply, NewState};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% internal
%%====================================================================

schedule_etl() ->
    erlang:send_after(?ETL_INTERVAL_MS, self(), run_etl).

run_etl_job(State) ->
    case read_watermark() of
        {ok, Watermark} ->
            case extract_transactions(Watermark) of
                {ok, []} ->
                    logger:info(#{action => <<"etl.skip">>, reason => <<"no_new_transactions">>, watermark => Watermark}),
                    State;
                {ok, Transactions} ->
                    Grouped = group_by_tenant_user(Transactions),
                    Today = date_to_binary(date()),
                    WatermarkDate = date_to_binary(watermark_to_date(Watermark)),
                    lists:foreach(fun({Key, Txns}) ->
                        {TenantId, UserId} = Key,
                        Summary = compute_summary(Txns),
                        upsert_snapshot(TenantId, UserId, <<"daily">>, WatermarkDate, Today, Summary)
                    end, maps:to_list(Grouped)),
                    %% Update watermark to last transaction's created_at
                    LastTxn = lists:last(Transactions),
                    NewWatermark = element(9, LastTxn),
                    update_watermark(NewWatermark),
                    logger:info(#{action => <<"etl.daily_complete">>, processed_count => length(Transactions), user_count => maps:size(Grouped)}),
                    %% Produce weekly snapshots from full-week data
                    produce_weekly_snapshots(Today),
                    State
            end;
        {error, Reason} ->
            logger:error(#{action => <<"etl.watermark_error">>, reason => Reason}),
            State
    end.

%%--------------------------------------------------------------------
%% DB helpers
%%--------------------------------------------------------------------

read_watermark() ->
    SQL = "SELECT last_processed_at FROM etl_metadata WHERE id = 'transaction_etl'",
    case pgapp:equery(SQL, []) of
        {ok, _, [{Watermark}]} -> {ok, Watermark};
        {ok, _, []}            -> {error, no_watermark_row};
        {error, Reason}        -> {error, Reason}
    end.

extract_transactions(Watermark) ->
    SQL = "SELECT tenant_id, user_id, wallet_id, type, gold_grams, price_eur_per_gram, "
          "gross_eur_cents, fee_eur_cents, created_at "
          "FROM transactions "
          "WHERE created_at > $1 AND status = 'posted' "
          "ORDER BY created_at ASC",
    case pgapp:equery(SQL, [Watermark]) of
        {ok, _, Rows} -> {ok, Rows};
        {error, Reason} -> {error, Reason}
    end.

upsert_snapshot(TenantId, UserId, Frequency, PeriodStart, PeriodEnd, Summary) ->
    SQL = "INSERT INTO insight_snapshots (id, tenant_id, user_id, frequency, period_start, period_end, summary, created_at) "
          "VALUES ($1, $2, $3, $4, $5, $6, $7, now()) "
          "ON CONFLICT (tenant_id, user_id, frequency, period_start, period_end) "
          "DO UPDATE SET summary = $7, created_at = now()",
    SnapshotId = uuid:uuid_to_string(uuid:get_v4_urandom(), binary_standard),
    SummaryJSON = jsx:encode(Summary),
    {ok, _} = pgapp:equery(SQL, [SnapshotId, TenantId, UserId, Frequency, PeriodStart, PeriodEnd, SummaryJSON]),
    ok.

update_watermark(NewWatermark) ->
    SQL = "UPDATE etl_metadata SET last_processed_at = $1, updated_at = now() WHERE id = 'transaction_etl'",
    {ok, _} = pgapp:equery(SQL, [NewWatermark]),
    ok.

%%--------------------------------------------------------------------
%% Transform helpers
%%--------------------------------------------------------------------

group_by_tenant_user(Transactions) ->
    lists:foldl(fun(Txn, Acc) ->
        TenantId = element(1, Txn),
        UserId = element(2, Txn),
        Key = {TenantId, UserId},
        maps:update_with(Key, fun(Existing) -> Existing ++ [Txn] end, [Txn], Acc)
    end, #{}, Transactions).

compute_summary(Txns) ->
    Raw = lists:foldl(fun(Txn, Acc) ->
        Type = element(4, Txn),
        GoldGrams = to_number(element(5, Txn)),
        PricePerGram = to_number(element(6, Txn)),
        FeeEurCents = element(8, Txn),
        case Type of
            <<"buy">> ->
                Acc#{
                    buy_count => maps:get(buy_count, Acc, 0) + 1,
                    total_gold_bought_grams => maps:get(total_gold_bought_grams, Acc, 0) + GoldGrams,
                    buy_price_sum => maps:get(buy_price_sum, Acc, 0) + PricePerGram,
                    total_fees_eur_cents => maps:get(total_fees_eur_cents, Acc, 0) + FeeEurCents
                };
            <<"sell">> ->
                Acc#{
                    sell_count => maps:get(sell_count, Acc, 0) + 1,
                    total_gold_sold_grams => maps:get(total_gold_sold_grams, Acc, 0) + GoldGrams,
                    sell_price_sum => maps:get(sell_price_sum, Acc, 0) + PricePerGram,
                    total_fees_eur_cents => maps:get(total_fees_eur_cents, Acc, 0) + FeeEurCents
                };
            _ ->
                Acc
        end
    end, #{}, Txns),
    finalize_summary(Raw).

finalize_summary(Raw) ->
    finalize_summary(Raw, daily).

finalize_summary(Raw, Period) ->
    BuyCount = maps:get(buy_count, Raw, 0),
    SellCount = maps:get(sell_count, Raw, 0),
    AvgBuyPrice = case BuyCount of
        0 -> 0;
        _ -> maps:get(buy_price_sum, Raw, 0) / BuyCount
    end,
    AvgSellPrice = case SellCount of
        0 -> 0;
        _ -> maps:get(sell_price_sum, Raw, 0) / SellCount
    end,
    %% Get current reference price
    RefPrice = case aurix_price_provider:get_price() of
        {ok, PriceCents} -> PriceCents / 100.0;
        _ -> 0
    end,
    %% sell_after_buy_ratio: use float division to avoid integer truncation
    SellAfterBuyRatio = case BuyCount of
        0 -> 0.0;
        _ -> SellCount * 1.0 / BuyCount
    end,
    %% buy_frequency_per_week: scale by period length
    DaysInPeriod = case Period of
        weekly -> 7;
        daily  -> 1
    end,
    BuyFreqPerWeek = case DaysInPeriod of
        7 -> BuyCount;
        D -> BuyCount * (7 / D)
    end,
    #{
        buy_count => BuyCount,
        sell_count => SellCount,
        total_gold_bought_grams => maps:get(total_gold_bought_grams, Raw, 0),
        total_gold_sold_grams => maps:get(total_gold_sold_grams, Raw, 0),
        total_fees_eur_cents => maps:get(total_fees_eur_cents, Raw, 0),
        average_buy_price_eur_per_gram => AvgBuyPrice,
        average_sell_price_eur_per_gram => AvgSellPrice,
        buy_frequency_per_week => BuyFreqPerWeek,
        sell_after_buy_ratio => SellAfterBuyRatio,
        reference_price_eur_per_gram => RefPrice,
        inactivity_days => 0
    }.

%%--------------------------------------------------------------------
%% Utility helpers
%%--------------------------------------------------------------------

to_number(V) when is_integer(V) -> V;
to_number(V) when is_float(V) -> V;
to_number(V) when is_binary(V) ->
    case binary:match(V, <<".">>) of
        nomatch -> binary_to_integer(V);
        _       -> binary_to_float(V)
    end.

date_to_binary({Y, M, D}) ->
    iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0B", [Y, M, D])).

watermark_to_date({{Y, M, D}, _Time}) -> {Y, M, D};
watermark_to_date({Y, M, D})          -> {Y, M, D}.

%% Get the Monday of the current week as a date binary
week_start_binary(Date) ->
    DayOfWeek = calendar:day_of_the_week(Date),
    DaysToSubtract = DayOfWeek - 1,
    GregDays = calendar:date_to_gregorian_days(Date) - DaysToSubtract,
    Monday = calendar:gregorian_days_to_date(GregDays),
    date_to_binary(Monday).

%%--------------------------------------------------------------------
%% Weekly snapshot aggregation
%%--------------------------------------------------------------------

produce_weekly_snapshots(Today) ->
    WeekStart = week_start_binary(date()),
    SQL = "SELECT tenant_id, user_id, type, gold_grams, price_eur_per_gram, fee_eur_cents "
          "FROM transactions "
          "WHERE created_at >= $1::date AND created_at < ($2::date + 1) AND status = 'posted' "
          "ORDER BY tenant_id, user_id",
    case pgapp:equery(SQL, [WeekStart, Today]) of
        {ok, _, []} -> ok;
        {ok, _, Rows} ->
            Grouped = group_weekly_rows(Rows),
            lists:foreach(fun({{TenantId, UserId}, Txns}) ->
                Summary = compute_weekly_summary(Txns),
                upsert_snapshot(TenantId, UserId, <<"weekly">>, WeekStart, Today, Summary)
            end, maps:to_list(Grouped)),
            logger:info(#{action => <<"etl.weekly_complete">>, snapshot_count => maps:size(Grouped)});
        {error, Reason} ->
            logger:error(#{action => <<"etl.weekly_error">>, reason => Reason})
    end.

group_weekly_rows(Rows) ->
    lists:foldl(fun(Row, Acc) ->
        TenantId = element(1, Row),
        UserId = element(2, Row),
        Key = {TenantId, UserId},
        maps:update_with(Key, fun(Existing) -> Existing ++ [Row] end, [Row], Acc)
    end, #{}, Rows).

compute_weekly_summary(Rows) ->
    Raw = lists:foldl(fun(Row, Acc) ->
        Type = element(3, Row),
        GoldGrams = to_number(element(4, Row)),
        PricePerGram = to_number(element(5, Row)),
        FeeEurCents = element(6, Row),
        case Type of
            <<"buy">> ->
                Acc#{
                    buy_count => maps:get(buy_count, Acc, 0) + 1,
                    total_gold_bought_grams => maps:get(total_gold_bought_grams, Acc, 0) + GoldGrams,
                    buy_price_sum => maps:get(buy_price_sum, Acc, 0) + PricePerGram,
                    total_fees_eur_cents => maps:get(total_fees_eur_cents, Acc, 0) + FeeEurCents
                };
            <<"sell">> ->
                Acc#{
                    sell_count => maps:get(sell_count, Acc, 0) + 1,
                    total_gold_sold_grams => maps:get(total_gold_sold_grams, Acc, 0) + GoldGrams,
                    sell_price_sum => maps:get(sell_price_sum, Acc, 0) + PricePerGram,
                    total_fees_eur_cents => maps:get(total_fees_eur_cents, Acc, 0) + FeeEurCents
                };
            _ -> Acc
        end
    end, #{}, Rows),
    finalize_summary(Raw, weekly).

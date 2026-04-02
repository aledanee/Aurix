-module(aurix_llm_adapter).

-export([generate_insights/1]).

%% Takes a summary signals map and returns a list of insight strings.
-spec generate_insights(Signals :: map()) -> [binary()].
generate_insights(Signals) ->
    Rules = [
        fun check_high_buy_frequency/1,
        fun check_buying_above_average/1,
        fun check_sell_after_buy/1,
        fun check_low_frequency_with_gold/1
    ],
    Insights = lists:filtermap(fun(Rule) ->
        case Rule(Signals) of
            {true, Insight} -> {true, Insight};
            false -> false
        end
    end, Rules),
    case Insights of
        [] -> [<<"Your trading activity looks balanced. Keep monitoring the market.">>];
        _ -> Insights
    end.

%% Internal rules

check_high_buy_frequency(Signals) ->
    BuyCount = to_number(maps:get(<<"buy_count">>, Signals, 0)),
    case BuyCount > 3 of
        true -> {true, <<"You are buying frequently. Consider spacing out your purchases to reduce timing risk.">>};
        false -> false
    end.

check_buying_above_average(Signals) ->
    AvgBuyPrice = to_number(maps:get(<<"average_buy_price_eur_per_gram">>, Signals, 0)),
    RefPrice = to_number(maps:get(<<"reference_price_eur_per_gram">>, Signals, 0)),
    case RefPrice > 0 andalso AvgBuyPrice > RefPrice * 1.05 of
        true -> {true, <<"You are buying at prices above the reference average. Consider waiting for a dip.">>};
        false -> false
    end.

check_sell_after_buy(Signals) ->
    BuyCount = to_number(maps:get(<<"buy_count">>, Signals, 0)),
    SellCount = to_number(maps:get(<<"sell_count">>, Signals, 0)),
    case BuyCount > 0 andalso (SellCount / BuyCount) > 0.5 of
        true -> {true, <<"You tend to sell shortly after buying. Consider holding longer to reduce fee impact.">>};
        false -> false
    end.

check_low_frequency_with_gold(Signals) ->
    BuyCount = to_number(maps:get(<<"buy_count">>, Signals, 0)),
    TotalGoldBought = to_number(maps:get(<<"total_gold_bought_grams">>, Signals, 0)),
    case BuyCount < 1 andalso TotalGoldBought > 0 of
        true -> {true, <<"You haven't bought recently. Consider dollar-cost averaging for consistent growth.">>};
        false -> false
    end.

to_number(V) when is_integer(V) -> V;
to_number(V) when is_float(V) -> V;
to_number(V) when is_binary(V) ->
    case binary:match(V, <<".">>) of
        nomatch -> binary_to_integer(V);
        _ -> binary_to_float(V)
    end;
to_number(_) -> 0.

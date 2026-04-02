-module(aurix_llm_adapter_tests).
-include_lib("eunit/include/eunit.hrl").

empty_signals_test() ->
    Result = aurix_llm_adapter:generate_insights(#{}),
    ?assert(is_list(Result)),
    ?assert(length(Result) > 0),
    %% Default message when no rules fire
    [First | _] = Result,
    ?assert(is_binary(First)).

high_buy_frequency_test() ->
    Signals = #{<<"buy_count">> => 5, <<"sell_count">> => 0},
    Result = aurix_llm_adapter:generate_insights(Signals),
    ?assert(lists:any(fun(I) -> binary:match(I, <<"buying frequently">>) =/= nomatch end, Result)).

buying_above_average_test() ->
    Signals = #{
        <<"average_buy_price_eur_per_gram">> => <<"70.00">>,
        <<"reference_price_eur_per_gram">> => <<"65.00">>
    },
    Result = aurix_llm_adapter:generate_insights(Signals),
    ?assert(lists:any(fun(I) -> binary:match(I, <<"above">>) =/= nomatch end, Result)).

sell_after_buy_ratio_test() ->
    Signals = #{<<"buy_count">> => 4, <<"sell_count">> => 3},
    Result = aurix_llm_adapter:generate_insights(Signals),
    ?assert(lists:any(fun(I) -> binary:match(I, <<"sell">>) =/= nomatch end, Result)).

balanced_activity_test() ->
    %% Signals that don't trigger any warning
    Signals = #{
        <<"buy_count">> => 2,
        <<"sell_count">> => 0,
        <<"average_buy_price_eur_per_gram">> => <<"65.00">>,
        <<"reference_price_eur_per_gram">> => <<"65.00">>
    },
    Result = aurix_llm_adapter:generate_insights(Signals),
    ?assert(lists:any(fun(I) -> binary:match(I, <<"balanced">>) =/= nomatch end, Result)).

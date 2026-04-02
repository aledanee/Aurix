-module(aurix_insight_handler).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            case aurix_auth_middleware:authenticate(Req0) of
                {ok, Claims} ->
                    TenantId = maps:get(<<"tenant_id">>, Claims),
                    UserId = maps:get(<<"sub">>, Claims),
                    QS = cowboy_req:parse_qs(Req0),
                    Limit = parse_limit(proplists:get_value(<<"limit">>, QS, <<"10">>), 50),
                    FreqFilter = proplists:get_value(<<"frequency">>, QS, undefined),
                    CursorParam = proplists:get_value(<<"cursor">>, QS, undefined),

                    Cursor = case CursorParam of
                        undefined -> undefined;
                        CursorBin ->
                            case aurix_repo_insight:decode_cursor(CursorBin) of
                                {ok, C} -> C;
                                {error, _} -> undefined
                            end
                    end,

                    Opts = #{limit => Limit, frequency => FreqFilter},
                    {ok, Items, NextCursor} = aurix_repo_insight:list_by_user(TenantId, UserId, Cursor, Opts),

                    FormattedItems = [format_insight(Item) || Item <- Items],
                    Response = #{
                        <<"items">> => FormattedItems,
                        <<"next_cursor">> => NextCursor
                    },
                    Body = jsx:encode(Response),
                    Req = cowboy_req:reply(200,
                        #{<<"content-type">> => <<"application/json">>},
                        Body, Req0),
                    {ok, Req, State};
                {error, Reason} ->
                    Req = reply_auth_error(Reason, Req0),
                    {ok, Req, State}
            end;
        _ ->
            Req = aurix_auth_middleware:reply_error(405, <<"method_not_allowed">>, <<"Method not allowed">>, Req0),
            {ok, Req, State}
    end.

%% Internal

format_insight(Item) ->
    Summary = maps:get(summary, Item, #{}),
    Insights = aurix_llm_adapter:generate_insights(Summary),
    #{
        <<"id">> => maps:get(id, Item),
        <<"frequency">> => maps:get(frequency, Item),
        <<"period_start">> => maps:get(period_start, Item),
        <<"period_end">> => maps:get(period_end, Item),
        <<"generated_at">> => maps:get(created_at, Item),
        <<"signals">> => Summary,
        <<"insights">> => Insights
    }.

parse_limit(Bin, Max) ->
    try
        L = binary_to_integer(Bin),
        max(1, min(Max, L))
    catch _:_ -> 10
    end.

reply_auth_error(unauthorized, Req) ->
    aurix_auth_middleware:reply_error(401, <<"unauthorized">>, <<"Authentication required">>, Req);
reply_auth_error(token_expired, Req) ->
    aurix_auth_middleware:reply_error(401, <<"token_expired">>, <<"Token has expired">>, Req).

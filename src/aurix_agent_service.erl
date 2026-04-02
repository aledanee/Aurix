-module(aurix_agent_service).

-export([list_insights/4]).

%% List AI-generated insights for a user with cursor-based pagination.
%% Opts: #{limit => integer(), frequency => binary() | undefined}
-spec list_insights(TenantId :: binary(), UserId :: binary(),
                    CursorParam :: binary() | undefined,
                    Opts :: map()) -> {ok, [map()], NextCursor :: binary() | null}.
list_insights(TenantId, UserId, CursorParam, Opts) ->
    Cursor = case CursorParam of
        undefined -> undefined;
        CursorBin ->
            case aurix_repo_insight:decode_cursor(CursorBin) of
                {ok, C} -> C;
                {error, _} -> undefined
            end
    end,
    {ok, Items, NextCursor} = aurix_repo_insight:list_by_user(TenantId, UserId, Cursor, Opts),
    FormattedItems = [format_insight(Item) || Item <- Items],
    {ok, FormattedItems, NextCursor}.

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

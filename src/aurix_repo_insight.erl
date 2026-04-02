-module(aurix_repo_insight).

-export([list_by_user/4, decode_cursor/1]).

%% List insight snapshots for a user with cursor-based pagination.
%% Opts: #{limit => integer(), frequency => binary() | undefined}
-spec list_by_user(TenantId :: binary(), UserId :: binary(),
                   Cursor :: undefined | {binary(), binary()},
                   Opts :: map()) -> {ok, [map()], NextCursor :: binary() | null}.
list_by_user(TenantId, UserId, Cursor, Opts) ->
    Limit = maps:get(limit, Opts, 10),
    Frequency = maps:get(frequency, Opts, undefined),
    FetchLimit = Limit + 1,
    {SQL, Params} = build_query(TenantId, UserId, Cursor, Frequency, FetchLimit),
    {ok, _Cols, Rows} = pgapp:equery(SQL, Params),
    Items = [row_to_map(Row) || Row <- Rows],
    case length(Items) > Limit of
        true ->
            PageItems = lists:sublist(Items, Limit),
            LastItem = lists:last(PageItems),
            NextCursor = encode_cursor(maps:get(created_at, LastItem), maps:get(id, LastItem)),
            {ok, PageItems, NextCursor};
        false ->
            {ok, Items, null}
    end.

-spec decode_cursor(binary()) -> {ok, {binary(), binary()}} | {error, invalid_cursor}.
decode_cursor(Cursor) ->
    try
        JSON = base64:decode(Cursor),
        #{<<"created_at">> := CreatedAt, <<"id">> := Id} = jsx:decode(JSON, [return_maps]),
        {ok, {CreatedAt, Id}}
    catch _:_ -> {error, invalid_cursor}
    end.

%% Internal

build_query(TenantId, UserId, undefined, undefined, Limit) ->
    SQL = "SELECT id, tenant_id, user_id, frequency, period_start, period_end, summary, created_at "
          "FROM insight_snapshots WHERE tenant_id = $1 AND user_id = $2 "
          "ORDER BY created_at DESC, id DESC LIMIT $3",
    {SQL, [TenantId, UserId, Limit]};

build_query(TenantId, UserId, undefined, Frequency, Limit) ->
    SQL = "SELECT id, tenant_id, user_id, frequency, period_start, period_end, summary, created_at "
          "FROM insight_snapshots WHERE tenant_id = $1 AND user_id = $2 AND frequency = $3 "
          "ORDER BY created_at DESC, id DESC LIMIT $4",
    {SQL, [TenantId, UserId, Frequency, Limit]};

build_query(TenantId, UserId, {CursorCreatedAt, CursorId}, undefined, Limit) ->
    SQL = "SELECT id, tenant_id, user_id, frequency, period_start, period_end, summary, created_at "
          "FROM insight_snapshots WHERE tenant_id = $1 AND user_id = $2 "
          "AND (created_at, id) < ($3, $4) "
          "ORDER BY created_at DESC, id DESC LIMIT $5",
    {SQL, [TenantId, UserId, CursorCreatedAt, CursorId, Limit]};

build_query(TenantId, UserId, {CursorCreatedAt, CursorId}, Frequency, Limit) ->
    SQL = "SELECT id, tenant_id, user_id, frequency, period_start, period_end, summary, created_at "
          "FROM insight_snapshots WHERE tenant_id = $1 AND user_id = $2 AND frequency = $3 "
          "AND (created_at, id) < ($4, $5) "
          "ORDER BY created_at DESC, id DESC LIMIT $6",
    {SQL, [TenantId, UserId, Frequency, CursorCreatedAt, CursorId, Limit]}.

row_to_map({Id, TenantId, UserId, Frequency, PeriodStart, PeriodEnd, Summary, CreatedAt}) ->
    %% Summary comes from jsonb — epgsql may return it as a binary JSON string
    DecodedSummary = case is_binary(Summary) of
        true -> jsx:decode(Summary, [return_maps]);
        false -> Summary
    end,
    #{
        id => Id,
        tenant_id => TenantId,
        user_id => UserId,
        frequency => Frequency,
        period_start => PeriodStart,
        period_end => PeriodEnd,
        summary => DecodedSummary,
        created_at => CreatedAt
    }.

encode_cursor(CreatedAt, Id) ->
    JSON = jsx:encode(#{<<"created_at">> => CreatedAt, <<"id">> => Id}),
    base64:encode(JSON).

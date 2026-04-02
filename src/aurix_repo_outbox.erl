-module(aurix_repo_outbox).

-export([insert/1, insert/2, get_unpublished/1, mark_published/1]).

%% Insert an outbox event (called within the same DB transaction as wallet update).
-spec insert(EventMap :: map()) -> ok.
insert(EventMap) ->
    SQL = "INSERT INTO outbox_events "
          "(tenant_id, aggregate_type, aggregate_id, event_type, payload, created_at) "
          "VALUES ($1, $2, $3, $4, $5, now())",
    #{
        tenant_id := TenantId,
        aggregate_type := AggType,
        aggregate_id := AggId,
        event_type := EventType,
        payload := Payload
    } = EventMap,
    PayloadJSON = jsx:encode(Payload),
    {ok, 1} = pgapp:equery(SQL, [TenantId, AggType, AggId, EventType, PayloadJSON]),
    ok.

%% Insert an outbox event within an existing DB transaction (takes a Conn pid).
-spec insert(pid(), map()) -> ok.
insert(Conn, EventMap) ->
    SQL = "INSERT INTO outbox_events "
          "(tenant_id, aggregate_type, aggregate_id, event_type, payload, created_at) "
          "VALUES ($1, $2, $3, $4, $5, now())",
    #{
        tenant_id := TenantId,
        aggregate_type := AggType,
        aggregate_id := AggId,
        event_type := EventType,
        payload := Payload
    } = EventMap,
    PayloadJSON = jsx:encode(Payload),
    {ok, 1} = epgsql:equery(Conn, SQL, [TenantId, AggType, AggId, EventType, PayloadJSON]),
    ok.

%% Get unpublished events (for outbox dispatcher polling).
-spec get_unpublished(Limit :: integer()) -> {ok, [map()]}.
get_unpublished(Limit) ->
    SQL = "SELECT id, tenant_id, aggregate_type, aggregate_id, event_type, payload, created_at "
          "FROM outbox_events WHERE published_at IS NULL ORDER BY id ASC LIMIT $1",
    {ok, _Cols, Rows} = pgapp:equery(SQL, [Limit]),
    {ok, [outbox_row_to_map(Row) || Row <- Rows]}.

%% Mark an event as published.
-spec mark_published(EventId :: integer()) -> ok.
mark_published(EventId) ->
    SQL = "UPDATE outbox_events SET published_at = now() WHERE id = $1",
    {ok, _} = pgapp:equery(SQL, [EventId]),
    ok.

%% Internal
outbox_row_to_map({Id, TenantId, AggType, AggId, EventType, Payload, CreatedAt}) ->
    #{
        id => Id,
        tenant_id => TenantId,
        aggregate_type => AggType,
        aggregate_id => AggId,
        event_type => EventType,
        payload => Payload,
        created_at => CreatedAt
    }.

-module(aurix_outbox_dispatcher).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(POLL_INTERVAL_MS, 5000).

-record(state, {}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    schedule_poll(),
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(poll, State) ->
    NewState = do_poll(State),
    schedule_poll(),
    {noreply, NewState};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% internal
%%====================================================================

schedule_poll() ->
    erlang:send_after(?POLL_INTERVAL_MS, self(), poll).

do_poll(State) ->
    case aurix_repo_outbox:get_unpublished(100) of
        {ok, []} ->
            State;
        {ok, Events} ->
            lists:foreach(fun publish_event/1, Events),
            State
    end.

publish_event(Event) ->
    EventType = maps:get(event_type, Event),
    EventId = maps:get(id, Event),
    TenantId = maps:get(tenant_id, Event),
    logger:info(#{action => <<"outbox.dispatch">>, event_id => EventId, event_type => EventType, tenant_id => TenantId}),
    %% In production: publish to Kafka here
    ok = aurix_repo_outbox:mark_published(EventId).

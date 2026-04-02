-module(aurix_etl_scheduler).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(ETL_INTERVAL_MS, 3600000). %% 1 hour

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
    schedule_etl(),
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

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
    %% TODO: implement ETL pipeline
    %% 1. Read watermark from etl_metadata
    %% 2. Extract transactions since watermark
    %% 3. Transform: group by (tenant_id, user_id), compute aggregates
    %% 4. Load: UPSERT into insight_snapshots
    %% 5. Update watermark
    State.

-module(aurix_rate_limiter).
-behaviour(gen_server).

-export([start_link/0, check_rate/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec check_rate(binary(), binary(), binary()) -> ok | {error, rate_limited}.
check_rate(TenantId, UserId, Endpoint) ->
    gen_server:call(?MODULE, {check_rate, TenantId, UserId, Endpoint}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    {ok, #state{}}.

handle_call({check_rate, _TenantId, _UserId, _Endpoint}, _From, State) ->
    %% TODO: implement Redis-backed sliding window rate limiting
    {reply, ok, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

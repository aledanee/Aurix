-module(aurix_redis).
-behaviour(gen_server).

%% API
-export([start_link/0, q/1, q/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(POOL_SIZE, 4).

-record(state, {
    conns :: tuple(),   %% tuple of eredis pids
    size :: integer(),
    counter :: integer()
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec q(iolist()) -> {ok, binary() | undefined} | {error, term()}.
q(Command) ->
    gen_server:call(?MODULE, {q, Command}).

-spec q(iolist(), timeout()) -> {ok, binary() | undefined} | {error, term()}.
q(Command, Timeout) ->
    gen_server:call(?MODULE, {q, Command}, Timeout).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    {ok, RedisConfig} = application:get_env(aurix, redis),
    Host = proplists:get_value(host, RedisConfig, "localhost"),
    Port = proplists:get_value(port, RedisConfig, 6379),
    Conns = list_to_tuple([begin
        {ok, C} = eredis:start_link(Host, Port),
        C
    end || _ <- lists:seq(1, ?POOL_SIZE)]),
    {ok, #state{conns = Conns, size = ?POOL_SIZE, counter = 0}}.

handle_call({q, Command}, _From, #state{conns = Conns, size = Size, counter = Counter} = State) ->
    Idx = (Counter rem Size) + 1,
    Conn = element(Idx, Conns),
    Result = eredis:q(Conn, Command),
    {reply, Result, State#state{counter = Counter + 1}};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{conns = Conns, size = Size}) ->
    lists:foreach(fun(I) -> eredis:stop(element(I, Conns)) end, lists:seq(1, Size)),
    ok.

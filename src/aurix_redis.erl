-module(aurix_redis).
-behaviour(gen_server).

%% API
-export([start_link/0, q/1, q/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    conn :: pid()
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
    {ok, Conn} = eredis:start_link(Host, Port),
    {ok, #state{conn = Conn}}.

handle_call({q, Command}, _From, #state{conn = Conn} = State) ->
    Result = eredis:q(Conn, Command),
    {reply, Result, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{conn = Conn}) ->
    eredis:stop(Conn),
    ok.

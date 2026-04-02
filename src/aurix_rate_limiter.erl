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

handle_call({check_rate, TenantId, UserId, Endpoint}, _From, State) ->
    Result = do_check_rate(TenantId, UserId, Endpoint),
    {reply, Result, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================

do_check_rate(TenantId, UserId, Endpoint) ->
    Limit = get_limit(Endpoint),
    Window = erlang:system_time(second) div 60,
    Key = iolist_to_binary([<<"rate:">>, Endpoint, <<":">>,
                            TenantId, <<":">>, UserId, <<":">>,
                            integer_to_binary(Window)]),
    case aurix_redis:q(["INCR", Key]) of
        {ok, CountBin} ->
            Count = binary_to_integer(CountBin),
            case Count of
                1 -> aurix_redis:q(["EXPIRE", Key, "60"]);
                _ -> ok
            end,
            case Count > Limit of
                true -> {error, rate_limited};
                false -> ok
            end;
        {error, _} ->
            %% Fail open — if Redis is down, allow the request
            ok
    end.

get_limit(<<"login">>) -> 10;
get_limit(<<"register">>) -> 5;
get_limit(<<"change_password">>) -> 5;
get_limit(<<"buy">>) -> 30;
get_limit(<<"sell">>) -> 30;
get_limit(<<"wallet">>) -> 60;
get_limit(<<"transactions">>) -> 60;
get_limit(<<"insights">>) -> 60;
get_limit(_) -> 60.

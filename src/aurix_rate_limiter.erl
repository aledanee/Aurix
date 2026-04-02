-module(aurix_rate_limiter).
-behaviour(gen_server).

-export([start_link/0, check_rate/3, check_rate/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec check_rate(binary(), binary(), binary()) -> {ok, map()} | {error, rate_limited, map()}.
check_rate(TenantId, UserId, Endpoint) ->
    gen_server:call(?MODULE, {check_rate, TenantId, UserId, Endpoint}).

%% Rate check with IP (for public endpoints like login/register)
-spec check_rate(binary(), binary(), binary(), binary()) -> {ok, map()} | {error, rate_limited, map()}.
check_rate(TenantId, UserId, Endpoint, Ip) ->
    gen_server:call(?MODULE, {check_rate, TenantId, UserId, Endpoint, Ip}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    {ok, #state{}}.

handle_call({check_rate, TenantId, UserId, Endpoint}, _From, State) ->
    Result = do_check_rate(TenantId, UserId, Endpoint),
    {reply, Result, State};
handle_call({check_rate, TenantId, _UserId, Endpoint, Ip}, _From, State) ->
    Result = do_check_rate_with_ip(TenantId, Endpoint, Ip),
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
    check_single_key(Key, Limit).

do_check_rate_with_ip(TenantId, Endpoint, Ip) ->
    Limit = get_limit(Endpoint),
    Window = erlang:system_time(second) div 60,
    IpKey = iolist_to_binary([<<"rate:">>, Endpoint, <<":ip:">>,
                              Ip, <<":">>, TenantId, <<":">>,
                              integer_to_binary(Window)]),
    check_single_key(IpKey, Limit).

check_single_key(Key, Limit) ->
    Window = erlang:system_time(second) div 60,
    Reset = (Window + 1) * 60,
    case aurix_redis:q(["INCR", Key]) of
        {ok, CountBin} ->
            Count = binary_to_integer(CountBin),
            case Count of
                1 -> aurix_redis:q(["EXPIRE", Key, "60"]);
                _ -> ok
            end,
            RateInfo = #{limit => Limit, remaining => max(0, Limit - Count), reset => Reset},
            case Count > Limit of
                true ->
                    logger:warning(#{action => <<"rate_limit.exceeded">>, key => Key, count => Count, limit => Limit}),
                    {error, rate_limited, RateInfo};
                false -> {ok, RateInfo}
            end;
        {error, _} ->
            %% Fail open — if Redis is down, allow the request
            {ok, #{limit => Limit, remaining => Limit, reset => Reset}}
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

-module(aurix_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% supervisor callbacks
%%====================================================================

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 60
    },
    Children = [
        child_spec(aurix_redis, worker),
        child_spec(aurix_price_provider, worker),
        child_spec(aurix_rate_limiter, worker),
        child_spec(aurix_outbox_dispatcher, worker),
        child_spec(aurix_etl_scheduler, worker),
        child_spec(aurix_reconciliation, worker),
        child_spec(aurix_http_sup, supervisor)
    ],
    {ok, {SupFlags, Children}}.

%%====================================================================
%% internal
%%====================================================================

child_spec(Module, Type) ->
    #{
        id => Module,
        start => {Module, start_link, []},
        restart => permanent,
        shutdown => 5000,
        type => Type,
        modules => [Module]
    }.

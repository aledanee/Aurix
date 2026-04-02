-module(aurix_http_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%%====================================================================
%% supervisor callbacks
%%====================================================================

init([]) ->
    Dispatch = aurix_router:dispatch(),
    Port = application:get_env(aurix, port, 8080),
    ChildSpecs = [
        ranch:child_spec(
            aurix_http_listener,
            ranch_tcp,
            [{port, Port}],
            cowboy_clear,
            #{env => #{dispatch => Dispatch},
              middlewares => [aurix_request_id_middleware, aurix_cors_middleware, cowboy_router, cowboy_handler]}
        )
    ],
    {ok, {#{strategy => one_for_one, intensity => 5, period => 60}, ChildSpecs}}.

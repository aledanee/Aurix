-module(aurix_app).
-behaviour(application).

-export([start/2, stop/1]).

%%====================================================================
%% application callbacks
%%====================================================================

start(_StartType, _StartArgs) ->
    ok = setup_cowboy(),
    aurix_sup:start_link().

stop(_State) ->
    ok = cowboy:stop_listener(aurix_http_listener),
    ok.

%%====================================================================
%% internal
%%====================================================================

setup_cowboy() ->
    Dispatch = aurix_router:dispatch(),
    Port = application:get_env(aurix, port, 8080),
    {ok, _} = cowboy:start_clear(
        aurix_http_listener,
        [{port, Port}],
        #{env => #{dispatch => Dispatch}}
    ),
    ok.

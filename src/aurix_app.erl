-module(aurix_app).
-behaviour(application).

-export([start/2, stop/1]).

%%====================================================================
%% application callbacks
%%====================================================================

start(_StartType, _StartArgs) ->
    ok = setup_database(),
    ok = setup_cowboy(),
    aurix_sup:start_link().

stop(_State) ->
    ok = cowboy:stop_listener(aurix_http_listener),
    ok.

%%====================================================================
%% internal
%%====================================================================

setup_database() ->
    {ok, DbConfig} = application:get_env(aurix, db),
    Host = proplists:get_value(host, DbConfig, "localhost"),
    Port = proplists:get_value(port, DbConfig, 5432),
    Database = proplists:get_value(database, DbConfig, "aurix_dev"),
    Username = proplists:get_value(username, DbConfig, "aurix"),
    Password = proplists:get_value(password, DbConfig, "aurix_dev_pass"),
    pgapp:connect([
        {host, Host},
        {port, Port},
        {database, Database},
        {username, Username},
        {password, Password},
        {size, 10}
    ]).

setup_cowboy() ->
    Dispatch = aurix_router:dispatch(),
    Port = application:get_env(aurix, port, 8080),
    {ok, _} = cowboy:start_clear(
        aurix_http_listener,
        [{port, Port}],
        #{env => #{dispatch => Dispatch}}
    ),
    ok.

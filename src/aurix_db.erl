-module(aurix_db).

-export([transaction/1, equery/3]).

%% Execute a function within a single database transaction.
%% Opens a dedicated connection, runs BEGIN, executes Fun(Conn),
%% then COMMIT on {ok, _} or ROLLBACK on {error, _} / exception.
-spec transaction(fun((pid()) -> {ok, term()} | {error, term()})) ->
    {ok, term()} | {error, term()}.
transaction(Fun) ->
    {ok, DbConfig} = application:get_env(aurix, db),
    ConnOpts = #{
        host => proplists:get_value(host, DbConfig, "localhost"),
        port => proplists:get_value(port, DbConfig, 5432),
        database => proplists:get_value(database, DbConfig, "aurix_dev"),
        username => proplists:get_value(username, DbConfig, "aurix"),
        password => proplists:get_value(password, DbConfig, "aurix_dev_pass")
    },
    {ok, Conn} = epgsql:connect(ConnOpts),
    try
        {ok, [], []} = epgsql:squery(Conn, "BEGIN"),
        case Fun(Conn) of
            {ok, _} = Result ->
                {ok, [], []} = epgsql:squery(Conn, "COMMIT"),
                Result;
            {error, _} = Error ->
                epgsql:squery(Conn, "ROLLBACK"),
                Error
        end
    catch
        Class:Reason:Stack ->
            epgsql:squery(Conn, "ROLLBACK"),
            logger:error("Transaction failed: ~p:~p~n~p", [Class, Reason, Stack]),
            {error, {transaction_failed, Reason}}
    after
        epgsql:close(Conn)
    end.

%% Execute a parameterized query on a specific connection (within a transaction).
-spec equery(pid(), iodata(), list()) -> term().
equery(Conn, SQL, Params) ->
    epgsql:equery(Conn, SQL, Params).

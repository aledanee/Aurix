-module(aurix_db).

-export([transaction/1, equery/3]).

%% Execute a function within a single database transaction.
%% Checks out a pgapp_worker from the pool for the entire transaction.
%% Queries inside Fun must use aurix_db:equery/3 with the Worker pid.
-spec transaction(fun((pid()) -> {ok, term()} | {error, term()})) ->
    {ok, term()} | {error, term()}.
transaction(Fun) ->
    Worker = poolboy:checkout(epgsql_pool),
    try
        case gen_server:call(Worker, {squery, "BEGIN"}) of
            {ok, [], []} ->
                case Fun(Worker) of
                    {ok, _} = Result ->
                        {ok, [], []} = gen_server:call(Worker, {squery, "COMMIT"}),
                        Result;
                    {error, _} = Error ->
                        gen_server:call(Worker, {squery, "ROLLBACK"}),
                        Error
                end;
            {error, disconnected} ->
                {error, {connection_failed, disconnected}}
        end
    catch
        Class:Reason:Stack ->
            catch gen_server:call(Worker, {squery, "ROLLBACK"}),
            logger:error(#{action => <<"db.transaction_failed">>, class => Class, reason => Reason, stacktrace => Stack}),
            {error, {transaction_failed, Reason}}
    after
        poolboy:checkin(epgsql_pool, Worker)
    end.

%% Execute a parameterized query on a pgapp_worker within a transaction.
-spec equery(pid(), iodata(), list()) -> term().
equery(Worker, SQL, Params) ->
    gen_server:call(Worker, {equery, SQL, Params}).

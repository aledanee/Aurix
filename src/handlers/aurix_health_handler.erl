-module(aurix_health_handler).

-export([init/2]).

init(Req0, State) ->
    DbStatus = check_database(),
    RedisStatus = check_redis(),
    AllUp = (DbStatus =:= <<"up">>) andalso (RedisStatus =:= <<"up">>),
    Status = case AllUp of
        true -> <<"healthy">>;
        false -> <<"degraded">>
    end,
    HttpCode = case AllUp of
        true -> 200;
        false -> 503
    end,
    Body = jsx:encode(#{
        <<"status">> => Status,
        <<"components">> => #{
            <<"api">> => <<"up">>,
            <<"database">> => DbStatus,
            <<"redis">> => RedisStatus
        },
        <<"timestamp">> => iso8601_now()
    }),
    Req = cowboy_req:reply(HttpCode,
        #{<<"content-type">> => <<"application/json">>},
        Body,
        Req0
    ),
    {ok, Req, State}.

%% Internal

check_database() ->
    try pgapp:equery("SELECT 1", []) of
        {ok, _, [{1}]} -> <<"up">>;
        _ -> <<"down">>
    catch
        _:_ -> <<"down">>
    end.

check_redis() ->
    try aurix_redis:q(["PING"]) of
        {ok, <<"PONG">>} -> <<"up">>;
        _ -> <<"down">>
    catch
        _:_ -> <<"down">>
    end.

iso8601_now() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:universal_time(),
    iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
                                    [Y, Mo, D, H, Mi, S])).

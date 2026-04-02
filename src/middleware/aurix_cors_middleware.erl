-module(aurix_cors_middleware).
-behaviour(cowboy_middleware).

-export([execute/2]).

execute(Req0, Env) ->
    AllowedOrigin = application:get_env(aurix, cors_origin, <<"http://localhost:3000">>),
    Req1 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, AllowedOrigin, Req0),
    Req2 = cowboy_req:set_resp_header(<<"access-control-allow-methods">>, <<"GET, POST, OPTIONS">>, Req1),
    Req3 = cowboy_req:set_resp_header(<<"access-control-allow-headers">>,
        <<"content-type, authorization, idempotency-key, x-request-id">>, Req2),
    Req4 = cowboy_req:set_resp_header(<<"access-control-max-age">>, <<"86400">>, Req3),
    case cowboy_req:method(Req4) of
        <<"OPTIONS">> ->
            Req5 = cowboy_req:reply(204, #{}, <<>>, Req4),
            {stop, Req5};
        _ ->
            {ok, Req4, Env}
    end.

-module(aurix_health_handler).

-export([init/2]).

%%====================================================================
%% Cowboy handler
%%====================================================================

init(Req0, State) ->
    Body = jsx:encode(#{
        <<"status">> => <<"ok">>,
        <<"service">> => <<"aurix">>,
        <<"version">> => <<"0.1.0">>
    }),
    Req = cowboy_req:reply(200,
        #{<<"content-type">> => <<"application/json">>},
        Body,
        Req0
    ),
    {ok, Req, State}.

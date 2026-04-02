-module(aurix_request_id_middleware).
-behaviour(cowboy_middleware).

-export([execute/2]).

execute(Req0, Env) ->
    RequestId = case cowboy_req:header(<<"x-request-id">>, Req0, undefined) of
        undefined ->
            uuid:uuid_to_string(uuid:get_v4_urandom(), binary_standard);
        Existing ->
            Existing
    end,
    Req1 = cowboy_req:set_resp_header(<<"x-request-id">>, RequestId, Req0),
    %% Store in request meta for downstream handlers
    Req2 = Req1#{request_id => RequestId},
    {ok, Req2, Env}.

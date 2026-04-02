-module(aurix_rate_headers).

-export([set_headers/2, reply_rate_limited/2]).

%% Add rate limit headers to a Cowboy request/response
-spec set_headers(RateInfo :: map(), cowboy_req:req()) -> cowboy_req:req().
set_headers(RateInfo, Req) ->
    #{limit := Limit, remaining := Remaining, reset := Reset} = RateInfo,
    Req1 = cowboy_req:set_resp_header(<<"x-ratelimit-limit">>, integer_to_binary(Limit), Req),
    Req2 = cowboy_req:set_resp_header(<<"x-ratelimit-remaining">>, integer_to_binary(Remaining), Req1),
    cowboy_req:set_resp_header(<<"x-ratelimit-reset">>, integer_to_binary(Reset), Req2).

%% Reply with 429 Too Many Requests including rate limit headers and Retry-After
-spec reply_rate_limited(RateInfo :: map(), cowboy_req:req()) -> cowboy_req:req().
reply_rate_limited(RateInfo, Req0) ->
    #{reset := Reset} = RateInfo,
    Now = erlang:system_time(second),
    RetryAfter = max(1, Reset - Now),
    Req1 = set_headers(RateInfo, Req0),
    Req2 = cowboy_req:set_resp_header(<<"retry-after">>, integer_to_binary(RetryAfter), Req1),
    Body = jsx:encode(#{
        <<"error">> => #{
            <<"code">> => <<"rate_limited">>,
            <<"message">> => <<"Too many requests">>
        }
    }),
    cowboy_req:reply(429, #{<<"content-type">> => <<"application/json">>}, Body, Req2).

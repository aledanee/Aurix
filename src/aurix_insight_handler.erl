-module(aurix_insight_handler).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            case aurix_auth_middleware:authenticate(Req0) of
                {ok, Claims} ->
                    TenantId = maps:get(<<"tenant_id">>, Claims),
                    UserId = maps:get(<<"sub">>, Claims),
                    case aurix_rate_limiter:check_rate(TenantId, UserId, <<"insights">>) of
                        {error, rate_limited, RateInfo} ->
                            Req = aurix_rate_headers:reply_rate_limited(RateInfo, Req0),
                            {ok, Req, State};
                        {ok, RateInfo} ->
                    Req1 = aurix_rate_headers:set_headers(RateInfo, Req0),
                    QS = cowboy_req:parse_qs(Req1),
                    Limit = parse_limit(proplists:get_value(<<"limit">>, QS, <<"10">>), 50),
                    FreqFilter = proplists:get_value(<<"frequency">>, QS, undefined),
                    CursorParam = proplists:get_value(<<"cursor">>, QS, undefined),

                    CacheKey = iolist_to_binary([<<"insights:">>, TenantId, <<":">>, UserId,
                        <<":">>, integer_to_binary(Limit),
                        case FreqFilter of undefined -> <<>>; F -> [<<":">>, F] end,
                        case CursorParam of undefined -> <<>>; CP -> [<<":">>, CP] end]),

                    case aurix_redis:q(["GET", CacheKey]) of
                        {ok, CachedBin} when is_binary(CachedBin) ->
                            %% Cache hit
                            Req = cowboy_req:reply(200,
                                #{<<"content-type">> => <<"application/json">>},
                                CachedBin, Req1),
                            {ok, Req, State};
                        _ ->
                            %% Cache miss or Redis error — query DB
                            Opts = #{limit => Limit, frequency => FreqFilter},
                            {ok, FormattedItems, NextCursor} = aurix_agent_service:list_insights(TenantId, UserId, CursorParam, Opts),
                            Response = #{
                                <<"items">> => FormattedItems,
                                <<"next_cursor">> => NextCursor
                            },
                            ResponseBin = jsx:encode(Response),
                            %% Cache with 5-minute TTL
                            catch aurix_redis:q(["SET", CacheKey, ResponseBin, "EX", "300"]),
                            Req = cowboy_req:reply(200,
                                #{<<"content-type">> => <<"application/json">>},
                                ResponseBin, Req1),
                            {ok, Req, State}
                    end
                    end;
                {error, Reason} ->
                    Req = reply_auth_error(Reason, Req0),
                    {ok, Req, State}
            end;
        _ ->
            Req = aurix_auth_middleware:reply_error(405, <<"method_not_allowed">>, <<"Method not allowed">>, Req0),
            {ok, Req, State}
    end.

%% Internal

parse_limit(Bin, Max) ->
    try
        L = binary_to_integer(Bin),
        max(1, min(Max, L))
    catch _:_ -> 10
    end.

reply_auth_error(unauthorized, Req) ->
    aurix_auth_middleware:reply_error(401, <<"unauthorized">>, <<"Authentication required">>, Req);
reply_auth_error(token_expired, Req) ->
    aurix_auth_middleware:reply_error(401, <<"token_expired">>, <<"Token has expired">>, Req).

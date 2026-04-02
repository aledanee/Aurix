-module(aurix_wallet_handler).

-export([init/2]).

init(Req0, #{action := Action} = State) ->
    case aurix_auth_middleware:authenticate(Req0) of
        {ok, Claims} ->
            TenantId = maps:get(<<"tenant_id">>, Claims),
            UserId = maps:get(<<"sub">>, Claims),
            RequestId = maps:get(request_id, Req0, undefined),
            logger:set_process_metadata(#{request_id => RequestId, tenant_id => TenantId, user_id => UserId}),
            Req = handle_action(Action, Claims, Req0),
            {ok, Req, State};
        {error, Reason} ->
            Req = reply_auth_error(Reason, Req0),
            {ok, Req, State}
    end.

%% GET /wallet
handle_action(view, Claims, Req0) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            TenantId = maps:get(<<"tenant_id">>, Claims),
            UserId = maps:get(<<"sub">>, Claims),
            case aurix_rate_limiter:check_rate(TenantId, UserId, <<"wallet">>) of
                {error, rate_limited, RateInfo} ->
                    aurix_rate_headers:reply_rate_limited(RateInfo, Req0);
                {ok, RateInfo} ->
                    Req1 = aurix_rate_headers:set_headers(RateInfo, Req0),
                    case aurix_wallet_service:view(TenantId, UserId) of
                        {ok, Wallet} ->
                            Response = format_wallet_response(Wallet),
                            reply_json(200, Response, Req1);
                        {error, not_found} ->
                            aurix_auth_middleware:reply_error(404, <<"wallet_not_found">>, <<"No wallet found">>, Req1)
                    end
            end;
        _ ->
            aurix_auth_middleware:reply_error(405, <<"method_not_allowed">>, <<"Method not allowed">>, Req0)
    end;

%% POST /wallet/buy
handle_action(buy, Claims, Req0) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            TenantId = maps:get(<<"tenant_id">>, Claims),
            UserId = maps:get(<<"sub">>, Claims),
            case aurix_rate_limiter:check_rate(TenantId, UserId, <<"buy">>) of
                {error, rate_limited, RateInfo} ->
                    aurix_rate_headers:reply_rate_limited(RateInfo, Req0);
                {ok, RateInfo} ->
                    Req1 = aurix_rate_headers:set_headers(RateInfo, Req0),
                    IdempotencyKey = cowboy_req:header(<<"idempotency-key">>, Req1, undefined),
                    case IdempotencyKey of
                        undefined ->
                            aurix_auth_middleware:reply_error(400, <<"bad_request">>, <<"Idempotency-Key header required">>, Req1);
                        _ ->
                            {ok, Body, Req2} = cowboy_req:read_body(Req1),
                            case jsx:decode(Body, [return_maps]) of
                                #{<<"grams">> := GramsStr} ->
                                    case validate_grams(GramsStr) of
                                        {ok, _} ->
                                            case aurix_wallet_service:buy(TenantId, UserId, GramsStr, IdempotencyKey) of
                                                {ok, Result} ->
                                                    reply_json(200, format_trade_response(Result), Req2);
                                                {ok, duplicate, _ExistingTxn} ->
                                                    aurix_auth_middleware:reply_error(409, <<"duplicate_request">>, <<"Duplicate idempotency key">>, Req2);
                                                {error, insufficient_balance} ->
                                                    aurix_auth_middleware:reply_error(422, <<"insufficient_balance">>, <<"Insufficient EUR balance">>, Req2);
                                                {error, Reason} ->
                                                    reply_service_error(Reason, Req2)
                                            end;
                                        error ->
                                            aurix_auth_middleware:reply_error(400, <<"invalid_amount">>, <<"Invalid grams value">>, Req2)
                                    end;
                                _ ->
                                    aurix_auth_middleware:reply_error(400, <<"bad_request">>, <<"Missing grams field">>, Req2)
                            end
                    end
            end;
        _ ->
            aurix_auth_middleware:reply_error(405, <<"method_not_allowed">>, <<"Method not allowed">>, Req0)
    end;

%% POST /wallet/sell
handle_action(sell, Claims, Req0) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            TenantId = maps:get(<<"tenant_id">>, Claims),
            UserId = maps:get(<<"sub">>, Claims),
            case aurix_rate_limiter:check_rate(TenantId, UserId, <<"sell">>) of
                {error, rate_limited, RateInfo} ->
                    aurix_rate_headers:reply_rate_limited(RateInfo, Req0);
                {ok, RateInfo} ->
                    Req1 = aurix_rate_headers:set_headers(RateInfo, Req0),
                    IdempotencyKey = cowboy_req:header(<<"idempotency-key">>, Req1, undefined),
                    case IdempotencyKey of
                        undefined ->
                            aurix_auth_middleware:reply_error(400, <<"bad_request">>, <<"Idempotency-Key header required">>, Req1);
                        _ ->
                            {ok, Body, Req2} = cowboy_req:read_body(Req1),
                            case jsx:decode(Body, [return_maps]) of
                                #{<<"grams">> := GramsStr} ->
                                    case validate_grams(GramsStr) of
                                        {ok, _} ->
                                            case aurix_wallet_service:sell(TenantId, UserId, GramsStr, IdempotencyKey) of
                                                {ok, Result} ->
                                                    reply_json(200, format_trade_response(Result), Req2);
                                                {ok, duplicate, _ExistingTxn} ->
                                                    aurix_auth_middleware:reply_error(409, <<"duplicate_request">>, <<"Duplicate idempotency key">>, Req2);
                                                {error, insufficient_gold} ->
                                                    aurix_auth_middleware:reply_error(422, <<"insufficient_gold">>, <<"Insufficient gold balance">>, Req2);
                                                {error, Reason} ->
                                                    reply_service_error(Reason, Req2)
                                            end;
                                        error ->
                                            aurix_auth_middleware:reply_error(400, <<"invalid_amount">>, <<"Invalid grams value">>, Req2)
                                    end;
                                _ ->
                                    aurix_auth_middleware:reply_error(400, <<"bad_request">>, <<"Missing grams field">>, Req2)
                            end
                    end
            end;
        _ ->
            aurix_auth_middleware:reply_error(405, <<"method_not_allowed">>, <<"Method not allowed">>, Req0)
    end.

%% Internal helpers

reply_json(StatusCode, Data, Req) ->
    Body = jsx:encode(Data),
    cowboy_req:reply(StatusCode, #{<<"content-type">> => <<"application/json">>}, Body, Req).

reply_auth_error(unauthorized, Req) ->
    aurix_auth_middleware:reply_error(401, <<"unauthorized">>, <<"Authentication required">>, Req);
reply_auth_error(token_expired, Req) ->
    aurix_auth_middleware:reply_error(401, <<"token_expired">>, <<"Token has expired">>, Req).

reply_service_error(wallet_not_found, Req) ->
    aurix_auth_middleware:reply_error(404, <<"wallet_not_found">>, <<"No wallet found">>, Req);
reply_service_error(invalid_amount, Req) ->
    aurix_auth_middleware:reply_error(400, <<"invalid_amount">>, <<"Invalid grams value">>, Req);
reply_service_error(_, Req) ->
    aurix_auth_middleware:reply_error(500, <<"internal_error">>, <<"An unexpected error occurred">>, Req).

validate_grams(GramsStr) when is_binary(GramsStr) ->
    try
        Val = binary_to_float(ensure_decimal(GramsStr)),
        case Val > 0 of
            true -> {ok, Val};
            false -> error
        end
    catch _:_ -> error
    end;
validate_grams(_) -> error.

ensure_decimal(Bin) ->
    case binary:match(Bin, <<".">>) of
        nomatch -> <<Bin/binary, ".0">>;
        _ -> Bin
    end.

%% Format wallet map for JSON response
format_wallet_response(Wallet) ->
    #{
        <<"wallet_id">> => maps:get(id, Wallet),
        <<"tenant_id">> => maps:get(tenant_id, Wallet),
        <<"user_id">> => maps:get(user_id, Wallet),
        <<"gold_balance_grams">> => format_gold(maps:get(gold_balance_grams, Wallet)),
        <<"fiat_balance_eur">> => format_eur(maps:get(fiat_balance_eur_cents, Wallet)),
        <<"updated_at">> => maps:get(updated_at, Wallet)
    }.

%% Format trade result for JSON response
format_trade_response(Result) ->
    Txn = maps:get(transaction, Result),
    Wallet = maps:get(wallet, Result, #{}),
    Type = maps:get(type, Txn),
    GrossEurCents = maps:get(gross_eur_cents, Txn),
    FeeEurCents = maps:get(fee_eur_cents, Txn),
    TxnResponse0 = #{
        <<"id">> => maps:get(id, Txn),
        <<"type">> => Type,
        <<"gold_grams">> => maps:get(gold_grams, Txn),
        <<"price_eur_per_gram">> => format_price(maps:get(price_eur_per_gram, Txn)),
        <<"gross_eur">> => format_eur(GrossEurCents),
        <<"fee_eur">> => format_eur(FeeEurCents),
        <<"created_at">> => iso8601_now()
    },
    TxnResponse = case Type of
        <<"buy">> -> TxnResponse0#{<<"total_eur">> => format_eur(GrossEurCents + FeeEurCents)};
        <<"sell">> -> TxnResponse0#{<<"net_eur">> => format_eur(GrossEurCents - FeeEurCents)};
        _ -> TxnResponse0
    end,
    Response = #{<<"transaction">> => TxnResponse},
    case maps:size(Wallet) > 0 of
        true ->
            Response#{<<"wallet">> => #{
                <<"gold_balance_grams">> => format_gold(maps:get(gold_balance_grams, Wallet)),
                <<"fiat_balance_eur">> => format_eur(maps:get(fiat_balance_eur_cents, Wallet))
            }};
        false ->
            Response
    end.

%% Convert integer cents to EUR string "81.25"
format_eur(Cents) when is_integer(Cents) ->
    Euros = Cents div 100,
    Remainder = abs(Cents rem 100),
    iolist_to_binary(io_lib:format("~B.~2..0B", [Euros, Remainder]));
format_eur(Val) ->
    Val.

%% Format gold grams to 8 decimal places
format_gold(Val) when is_number(Val) ->
    iolist_to_binary(io_lib:format("~.8f", [Val * 1.0]));
format_gold(Val) when is_binary(Val) ->
    Val.

%% Format price to 8 decimal places
format_price(Val) when is_number(Val) ->
    iolist_to_binary(io_lib:format("~.8f", [Val * 1.0]));
format_price(Val) when is_binary(Val) -> Val.

iso8601_now() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:universal_time(),
    iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
                                    [Y, Mo, D, H, Mi, S])).

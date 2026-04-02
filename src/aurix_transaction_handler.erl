-module(aurix_transaction_handler).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            case aurix_auth_middleware:authenticate(Req0) of
                {ok, Claims} ->
                    TenantId = maps:get(<<"tenant_id">>, Claims),
                    UserId = maps:get(<<"sub">>, Claims),
                    QS = cowboy_req:parse_qs(Req0),
                    Limit = parse_limit(proplists:get_value(<<"limit">>, QS, <<"20">>)),
                    TypeFilter = proplists:get_value(<<"type">>, QS, undefined),
                    CursorParam = proplists:get_value(<<"cursor">>, QS, undefined),

                    Cursor = case CursorParam of
                        undefined -> undefined;
                        CursorBin ->
                            case aurix_repo_transaction:decode_cursor(CursorBin) of
                                {ok, C} -> C;
                                {error, _} -> undefined
                            end
                    end,

                    Opts = #{limit => Limit, type => TypeFilter},
                    {ok, Items, NextCursor} = aurix_repo_transaction:list_by_user(TenantId, UserId, Cursor, Opts),

                    FormattedItems = [format_transaction(Item) || Item <- Items],
                    Response = #{
                        <<"items">> => FormattedItems,
                        <<"next_cursor">> => NextCursor
                    },
                    Req = reply_json(200, Response, Req0),
                    {ok, Req, State};
                {error, Reason} ->
                    Req = reply_auth_error(Reason, Req0),
                    {ok, Req, State}
            end;
        _ ->
            Req = aurix_auth_middleware:reply_error(405, <<"method_not_allowed">>, <<"Method not allowed">>, Req0),
            {ok, Req, State}
    end.

%% Internal

format_transaction(Txn) ->
    #{
        <<"id">> => maps:get(id, Txn),
        <<"type">> => maps:get(type, Txn),
        <<"gold_grams">> => format_gold(maps:get(gold_grams, Txn)),
        <<"price_eur_per_gram">> => format_gold(maps:get(price_eur_per_gram, Txn)),
        <<"gross_eur">> => format_eur(maps:get(gross_eur_cents, Txn)),
        <<"fee_eur">> => format_eur(maps:get(fee_eur_cents, Txn)),
        <<"status">> => maps:get(status, Txn),
        <<"created_at">> => maps:get(created_at, Txn)
    }.

format_eur(Cents) when is_integer(Cents) ->
    Euros = Cents div 100,
    Remainder = abs(Cents rem 100),
    iolist_to_binary(io_lib:format("~B.~2..0B", [Euros, Remainder]));
format_eur(Val) -> Val.

format_gold(Val) when is_number(Val) ->
    iolist_to_binary(io_lib:format("~.8f", [Val * 1.0]));
format_gold(Val) when is_binary(Val) -> Val.

parse_limit(Bin) ->
    try
        L = binary_to_integer(Bin),
        max(1, min(100, L))
    catch _:_ -> 20
    end.

reply_json(StatusCode, Data, Req) ->
    Body = jsx:encode(Data),
    cowboy_req:reply(StatusCode, #{<<"content-type">> => <<"application/json">>}, Body, Req).

reply_auth_error(unauthorized, Req) ->
    aurix_auth_middleware:reply_error(401, <<"unauthorized">>, <<"Authentication required">>, Req);
reply_auth_error(token_expired, Req) ->
    aurix_auth_middleware:reply_error(401, <<"token_expired">>, <<"Token has expired">>, Req).

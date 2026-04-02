-module(aurix_privacy_handler).

-export([init/2]).

init(Req0, #{action := Action} = State) ->
    case aurix_auth_middleware:authenticate(Req0) of
        {ok, Claims} ->
            Req = handle_action(Action, Claims, Req0),
            {ok, Req, State};
        {error, Reason} ->
            Req = reply_auth_error(Reason, Req0),
            {ok, Req, State}
    end.

%% GET /privacy/export
handle_action(export, Claims, Req0) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            TenantId = maps:get(<<"tenant_id">>, Claims),
            UserId = maps:get(<<"sub">>, Claims),
            Email = maps:get(<<"email">>, Claims),

            %% Get user created_at from DB
            UserCreatedAt = case aurix_repo_user:get_by_id(TenantId, UserId) of
                {ok, UserRecord} -> maps:get(created_at, UserRecord);
                _ -> null
            end,

            %% Gather user data
            WalletData = case aurix_repo_wallet:get_by_user_id(TenantId, UserId) of
                {ok, W} -> #{
                    <<"gold_balance_grams">> => format_gold(maps:get(gold_balance_grams, W)),
                    <<"fiat_balance_eur">> => format_eur(maps:get(fiat_balance_eur_cents, W))
                };
                _ -> #{}
            end,

            %% Gather transactions
            {ok, TxnItems, _} = aurix_repo_transaction:list_by_user(TenantId, UserId, undefined, #{limit => 1000}),
            FormattedTxns = [#{
                <<"id">> => maps:get(id, T),
                <<"type">> => maps:get(type, T),
                <<"gold_grams">> => format_gold(maps:get(gold_grams, T)),
                <<"gross_eur">> => format_eur(maps:get(gross_eur_cents, T)),
                <<"created_at">> => maps:get(created_at, T)
            } || T <- TxnItems],

            %% Gather insights
            {ok, InsightItems, _} = aurix_repo_insight:list_by_user(TenantId, UserId, undefined, #{limit => 100}),

            Response = #{
                <<"user">> => #{
                    <<"id">> => UserId,
                    <<"email">> => Email,
                    <<"created_at">> => UserCreatedAt
                },
                <<"wallet">> => WalletData,
                <<"transactions">> => FormattedTxns,
                <<"insights">> => [maps:get(summary, I, #{}) || I <- InsightItems],
                <<"exported_at">> => iso8601_now()
            },
            Body = jsx:encode(Response),
            Req = cowboy_req:reply(200,
                #{<<"content-type">> => <<"application/json">>},
                Body, Req0),
            Req;
        _ ->
            aurix_auth_middleware:reply_error(405, <<"method_not_allowed">>, <<"Method not allowed">>, Req0)
    end;

%% POST /privacy/erasure-request
handle_action(erasure, Claims, Req0) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            TenantId = maps:get(<<"tenant_id">>, Claims),
            UserId = maps:get(<<"sub">>, Claims),
            case aurix_privacy_service:request_erasure(TenantId, UserId) of
                ok ->
                    RequestId = uuid:uuid_to_string(uuid:get_v4_urandom(), binary_standard),
                    Response = #{
                        <<"status">> => <<"accepted">>,
                        <<"message">> => <<"Your account has been disabled. Personal data will be erased according to our retention policy.">>,
                        <<"request_id">> => RequestId
                    },
                    Body = jsx:encode(Response),
                    cowboy_req:reply(202,
                        #{<<"content-type">> => <<"application/json">>},
                        Body, Req0);
                {error, not_found} ->
                    aurix_auth_middleware:reply_error(404, <<"not_found">>, <<"User not found">>, Req0)
            end;
        _ ->
            aurix_auth_middleware:reply_error(405, <<"method_not_allowed">>, <<"Method not allowed">>, Req0)
    end.

%% Internal

reply_auth_error(unauthorized, Req) ->
    aurix_auth_middleware:reply_error(401, <<"unauthorized">>, <<"Authentication required">>, Req);
reply_auth_error(token_expired, Req) ->
    aurix_auth_middleware:reply_error(401, <<"token_expired">>, <<"Token has expired">>, Req).

iso8601_now() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:universal_time(),
    iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
                                    [Y, Mo, D, H, Mi, S])).

format_eur(Cents) when is_integer(Cents) ->
    Euros = Cents div 100,
    Remainder = abs(Cents rem 100),
    iolist_to_binary(io_lib:format("~B.~2..0B", [Euros, Remainder]));
format_eur(Val) -> Val.

format_gold(Val) when is_number(Val) ->
    iolist_to_binary(io_lib:format("~.8f", [Val * 1.0]));
format_gold(Val) when is_binary(Val) -> Val.

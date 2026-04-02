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

            %% Gather user data
            WalletData = case aurix_repo_wallet:get_by_user_id(TenantId, UserId) of
                {ok, W} -> #{
                    <<"gold_balance_grams">> => maps:get(gold_balance_grams, W),
                    <<"fiat_balance_eur_cents">> => maps:get(fiat_balance_eur_cents, W)
                };
                _ -> #{}
            end,

            Response = #{
                <<"user">> => #{
                    <<"id">> => UserId,
                    <<"email">> => Email
                },
                <<"wallet">> => WalletData,
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
            UserId = maps:get(<<"sub">>, Claims),
            %% Log the erasure request (actual implementation will be Phase 4)
            logger:info("Erasure request received for user ~s", [UserId]),
            Response = #{
                <<"status">> => <<"accepted">>,
                <<"message">> => <<"Erasure request has been submitted and will be processed">>
            },
            Body = jsx:encode(Response),
            Req = cowboy_req:reply(202,
                #{<<"content-type">> => <<"application/json">>},
                Body, Req0),
            Req;
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

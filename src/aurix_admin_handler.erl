-module(aurix_admin_handler).

-export([init/2]).

init(Req0, #{action := Action} = State) ->
    case aurix_auth_middleware:authenticate(Req0) of
        {ok, Claims} ->
            case maps:get(<<"role">>, Claims, <<"user">>) of
                <<"admin">> ->
                    RequestId = maps:get(request_id, Req0, undefined),
                    TenantId = maps:get(<<"tenant_id">>, Claims),
                    UserId = maps:get(<<"sub">>, Claims),
                    logger:set_process_metadata(#{request_id => RequestId, tenant_id => TenantId, user_id => UserId}),
                    Req = handle_action(Action, Req0),
                    {ok, Req, State};
                _ ->
                    Req = aurix_auth_middleware:reply_error(403, <<"forbidden">>, <<"Admin access required">>, Req0),
                    {ok, Req, State}
            end;
        {error, Reason} ->
            Req = reply_auth_error(Reason, Req0),
            {ok, Req, State}
    end.

%% US-4.2 — GET /admin/tenants
handle_action(list_tenants, Req0) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            {ok, Tenants} = aurix_admin_service:list_tenants(),
            Formatted = [format_tenant(T) || T <- Tenants],
            reply_json(200, #{<<"items">> => Formatted}, Req0);
        _ ->
            aurix_auth_middleware:reply_error(405, <<"method_not_allowed">>, <<"Method not allowed">>, Req0)
    end;

%% US-4.3 — POST /admin/tenants/:id/deactivate
handle_action(deactivate_tenant, Req0) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            TenantId = cowboy_req:binding(tenant_id, Req0),
            case aurix_admin_service:deactivate_tenant(TenantId) of
                ok ->
                    reply_json(200, #{<<"status">> => <<"deactivated">>, <<"tenant_id">> => TenantId}, Req0);
                {error, not_found} ->
                    aurix_auth_middleware:reply_error(404, <<"not_found">>, <<"Tenant not found">>, Req0)
            end;
        _ ->
            aurix_auth_middleware:reply_error(405, <<"method_not_allowed">>, <<"Method not allowed">>, Req0)
    end;

%% US-4.5 — POST /admin/gold-price
handle_action(update_gold_price, Req0) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            {ok, Body, Req1} = cowboy_req:read_body(Req0),
            case jsx:decode(Body, [return_maps]) of
                #{<<"price_eur">> := PriceEur} when is_binary(PriceEur) ->
                    case aurix_admin_service:update_gold_price(PriceEur) of
                        ok ->
                            reply_json(200, #{<<"status">> => <<"updated">>, <<"price_eur">> => PriceEur}, Req1);
                        {error, invalid_price} ->
                            aurix_auth_middleware:reply_error(400, <<"invalid_price">>, <<"Price must be a positive decimal">>, Req1)
                    end;
                _ ->
                    aurix_auth_middleware:reply_error(400, <<"bad_request">>, <<"Missing price_eur field">>, Req1)
            end;
        _ ->
            aurix_auth_middleware:reply_error(405, <<"method_not_allowed">>, <<"Method not allowed">>, Req0)
    end.

%% Internal

format_tenant(T) ->
    #{
        <<"id">> => maps:get(id, T),
        <<"code">> => maps:get(code, T),
        <<"name">> => maps:get(name, T),
        <<"status">> => maps:get(status, T),
        <<"created_at">> => maps:get(created_at, T)
    }.

reply_json(StatusCode, Data, Req) ->
    Body = jsx:encode(Data),
    cowboy_req:reply(StatusCode, #{<<"content-type">> => <<"application/json">>}, Body, Req).

reply_auth_error(unauthorized, Req) ->
    aurix_auth_middleware:reply_error(401, <<"unauthorized">>, <<"Authentication required">>, Req);
reply_auth_error(token_expired, Req) ->
    aurix_auth_middleware:reply_error(401, <<"token_expired">>, <<"Token has expired">>, Req).

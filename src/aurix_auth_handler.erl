-module(aurix_auth_handler).

-export([init/2]).

%%====================================================================
%% Cowboy handler
%%====================================================================

init(Req0, #{action := Action} = State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            Req = handle_action(Action, Req0),
            {ok, Req, State};
        _ ->
            Req = aurix_auth_middleware:reply_error(405, <<"method_not_allowed">>, <<"Method not allowed">>, Req0),
            {ok, Req, State}
    end.

%%====================================================================
%% Actions
%%====================================================================

handle_action(register, Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    case jsx:decode(Body, [return_maps]) of
        #{<<"tenant_code">> := TenantCode, <<"email">> := Email, <<"password">> := Password} ->
            Ip = peer_ip(Req1),
            case aurix_rate_limiter:check_rate(TenantCode, <<"anonymous">>, <<"register">>, Ip) of
                {error, rate_limited, RateInfo} ->
                    aurix_rate_headers:reply_rate_limited(RateInfo, Req1);
                {ok, RateInfo} ->
                    Req2 = aurix_rate_headers:set_headers(RateInfo, Req1),
                    case validate_email(Email) of
                        ok ->
                            case aurix_auth_service:register(TenantCode, Email, Password) of
                                {ok, Result} ->
                                    reply_json(201, Result, Req2);
                                {error, Reason} ->
                                    reply_service_error(Reason, Req2)
                            end;
                        error ->
                            aurix_auth_middleware:reply_error(400, <<"invalid_email">>, <<"Invalid email format">>, Req2)
                    end
            end;
        _ ->
            aurix_auth_middleware:reply_error(400, <<"bad_request">>, <<"Missing required fields">>, Req1)
    end;

handle_action(login, Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    case jsx:decode(Body, [return_maps]) of
        #{<<"tenant_code">> := TenantCode, <<"email">> := Email, <<"password">> := Password} ->
            Ip = peer_ip(Req1),
            case aurix_rate_limiter:check_rate(TenantCode, <<"anonymous">>, <<"login">>, Ip) of
                {error, rate_limited, RateInfo} ->
                    aurix_rate_headers:reply_rate_limited(RateInfo, Req1);
                {ok, RateInfo} ->
                    Req2 = aurix_rate_headers:set_headers(RateInfo, Req1),
                    case aurix_auth_service:login(TenantCode, Email, Password) of
                        {ok, Tokens} ->
                            reply_json(200, Tokens, Req2);
                        {error, Reason} ->
                            reply_service_error(Reason, Req2)
                    end
            end;
        _ ->
            aurix_auth_middleware:reply_error(400, <<"bad_request">>, <<"Missing required fields">>, Req1)
    end;

handle_action(refresh, Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    case jsx:decode(Body, [return_maps]) of
        #{<<"refresh_token">> := RefreshToken} ->
            case aurix_auth_service:refresh(RefreshToken) of
                {ok, Tokens} ->
                    reply_json(200, Tokens, Req1);
                {error, Reason} ->
                    reply_service_error(Reason, Req1)
            end;
        _ ->
            aurix_auth_middleware:reply_error(400, <<"bad_request">>, <<"Missing refresh_token">>, Req1)
    end;

handle_action(logout, Req0) ->
    case aurix_auth_middleware:authenticate(Req0) of
        {ok, _Claims} ->
            {ok, Body, Req1} = cowboy_req:read_body(Req0),
            case jsx:decode(Body, [return_maps]) of
                #{<<"refresh_token">> := RefreshToken} ->
                    case aurix_auth_service:logout(RefreshToken) of
                        ok ->
                            cowboy_req:reply(204, #{}, <<>>, Req1);
                        {error, Reason} ->
                            reply_service_error(Reason, Req1)
                    end;
                _ ->
                    aurix_auth_middleware:reply_error(400, <<"bad_request">>, <<"Missing refresh_token">>, Req1)
            end;
        {error, Reason} ->
            reply_auth_error(Reason, Req0)
    end;

handle_action(change_password, Req0) ->
    case aurix_auth_middleware:authenticate(Req0) of
        {ok, Claims} ->
            TenantId = maps:get(<<"tenant_id">>, Claims),
            UserId = maps:get(<<"sub">>, Claims),
            case aurix_rate_limiter:check_rate(TenantId, UserId, <<"change_password">>) of
                {error, rate_limited, RateInfo} ->
                    aurix_rate_headers:reply_rate_limited(RateInfo, Req0);
                {ok, RateInfo} ->
                    Req1a = aurix_rate_headers:set_headers(RateInfo, Req0),
                    {ok, Body, Req1} = cowboy_req:read_body(Req1a),
                    case jsx:decode(Body, [return_maps]) of
                        #{<<"current_password">> := CurrentPw, <<"new_password">> := NewPw} ->
                            case aurix_auth_service:change_password(TenantId, UserId, CurrentPw, NewPw) of
                                ok ->
                                    cowboy_req:reply(204, #{}, <<>>, Req1);
                                {error, Reason} ->
                                    reply_service_error(Reason, Req1)
                            end;
                        _ ->
                            aurix_auth_middleware:reply_error(400, <<"bad_request">>, <<"Missing required fields">>, Req1)
                    end
            end;
        {error, Reason} ->
            reply_auth_error(Reason, Req0)
    end.

%%====================================================================
%% Internal
%%====================================================================

reply_json(StatusCode, Data, Req) ->
    Body = jsx:encode(Data),
    cowboy_req:reply(StatusCode,
        #{<<"content-type">> => <<"application/json">>},
        Body,
        Req).

reply_auth_error(unauthorized, Req) ->
    aurix_auth_middleware:reply_error(401, <<"unauthorized">>, <<"Authentication required">>, Req);
reply_auth_error(token_expired, Req) ->
    aurix_auth_middleware:reply_error(401, <<"token_expired">>, <<"Token has expired">>, Req).

reply_service_error(invalid_tenant, Req) ->
    aurix_auth_middleware:reply_error(400, <<"invalid_tenant">>, <<"Tenant not found">>, Req);
reply_service_error(tenant_inactive, Req) ->
    aurix_auth_middleware:reply_error(403, <<"tenant_inactive">>, <<"Tenant is deactivated">>, Req);
reply_service_error(invalid_email, Req) ->
    aurix_auth_middleware:reply_error(400, <<"invalid_email">>, <<"Invalid email format">>, Req);
reply_service_error(invalid_password, Req) ->
    aurix_auth_middleware:reply_error(400, <<"invalid_password">>, <<"Password does not meet requirements">>, Req);
reply_service_error(email_taken, Req) ->
    aurix_auth_middleware:reply_error(409, <<"email_taken">>, <<"Email already registered in this tenant">>, Req);
reply_service_error(invalid_credentials, Req) ->
    aurix_auth_middleware:reply_error(401, <<"invalid_credentials">>, <<"Invalid email or password">>, Req);
reply_service_error(account_disabled, Req) ->
    aurix_auth_middleware:reply_error(403, <<"account_disabled">>, <<"Account is disabled">>, Req);
reply_service_error(unauthorized, Req) ->
    aurix_auth_middleware:reply_error(401, <<"unauthorized">>, <<"Authentication required">>, Req);
reply_service_error(token_revoked, Req) ->
    aurix_auth_middleware:reply_error(401, <<"token_revoked">>, <<"Refresh token was revoked">>, Req);
reply_service_error(token_expired, Req) ->
    aurix_auth_middleware:reply_error(401, <<"token_expired">>, <<"Refresh token has expired">>, Req);
reply_service_error(password_unchanged, Req) ->
    aurix_auth_middleware:reply_error(400, <<"invalid_password">>, <<"New password must differ from current password">>, Req);
reply_service_error(_, Req) ->
    aurix_auth_middleware:reply_error(500, <<"internal_error">>, <<"An unexpected error occurred">>, Req).

%% Basic email format validation
validate_email(Email) when is_binary(Email) ->
    case binary:match(Email, <<"@">>) of
        {Pos, _} when Pos > 0 ->
            %% Check there's something after @
            AfterAt = byte_size(Email) - Pos - 1,
            case AfterAt > 0 of
                true -> ok;
                false -> error
            end;
        _ ->
            error
    end;
validate_email(_) ->
    error.

peer_ip(Req) ->
    %% Prefer X-Forwarded-For header (behind proxy), fallback to direct peer
    case cowboy_req:header(<<"x-forwarded-for">>, Req, undefined) of
        undefined ->
            {IpTuple, _Port} = cowboy_req:peer(Req),
            iolist_to_binary(inet:ntoa(IpTuple));
        Forwarded ->
            %% Take the first IP (leftmost = original client)
            [FirstIp | _] = binary:split(Forwarded, <<", ">>),
            string:trim(FirstIp)
    end.

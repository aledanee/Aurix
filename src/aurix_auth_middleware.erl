-module(aurix_auth_middleware).

-export([authenticate/1, reply_error/4]).

%%====================================================================
%% API
%%====================================================================

%% Extracts and validates JWT from the Authorization header.
-spec authenticate(cowboy_req:req()) ->
    {ok, Claims :: map()} | {error, unauthorized | token_expired}.
authenticate(Req) ->
    case cowboy_req:header(<<"authorization">>, Req) of
        undefined ->
            {error, unauthorized};
        AuthHeader ->
            case parse_bearer(AuthHeader) of
                {ok, Token} ->
                    case aurix_jwt:verify_token(Token) of
                        {ok, Claims} ->
                            case validate_claims(Claims) of
                                ok -> {ok, Claims};
                                error -> {error, unauthorized}
                            end;
                        {error, token_expired} ->
                            {error, token_expired};
                        {error, invalid_token} ->
                            {error, unauthorized}
                    end;
                error ->
                    {error, unauthorized}
            end
    end.

%% Returns a JSON error response via Cowboy.
-spec reply_error(StatusCode :: integer(), ErrorCode :: binary(),
                  Message :: binary(), cowboy_req:req()) -> cowboy_req:req().
reply_error(StatusCode, ErrorCode, Message, Req) ->
    Body = jsx:encode(#{
        <<"error">> => #{
            <<"code">> => ErrorCode,
            <<"message">> => Message
        }
    }),
    cowboy_req:reply(StatusCode,
        #{<<"content-type">> => <<"application/json">>},
        Body,
        Req).

%%====================================================================
%% Internal
%%====================================================================

-spec parse_bearer(binary()) -> {ok, binary()} | error.
parse_bearer(<<"Bearer ", Token/binary>>) when byte_size(Token) > 0 ->
    {ok, Token};
parse_bearer(<<"bearer ", Token/binary>>) when byte_size(Token) > 0 ->
    {ok, Token};
parse_bearer(_) ->
    error.

-spec validate_claims(map()) -> ok | error.
validate_claims(Claims) ->
    case {maps:is_key(<<"sub">>, Claims),
          maps:is_key(<<"tenant_id">>, Claims),
          maps:is_key(<<"email">>, Claims)} of
        {true, true, true} -> ok;
        _ -> error
    end.

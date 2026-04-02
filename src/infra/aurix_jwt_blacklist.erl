-module(aurix_jwt_blacklist).

-export([blacklist_user/1, is_blacklisted/2]).

%% Blacklist all tokens issued before now for this user.
%% Called after password change.
-spec blacklist_user(UserId :: binary()) -> ok.
blacklist_user(UserId) ->
    Key = <<"jwt:blacklist:", UserId/binary>>,
    Now = integer_to_binary(erlang:system_time(second)),
    %% Any token with iat =< Now is invalid. TTL = max access token lifetime.
    aurix_redis:q(["SET", Key, Now, "EX", "900"]),
    ok.

%% Check if a token's iat is before the blacklist timestamp.
-spec is_blacklisted(UserId :: binary(), Iat :: integer()) -> boolean().
is_blacklisted(UserId, Iat) ->
    Key = <<"jwt:blacklist:", UserId/binary>>,
    case aurix_redis:q(["GET", Key]) of
        {ok, undefined} -> false;
        {ok, BlacklistTimeBin} ->
            BlacklistTime = binary_to_integer(BlacklistTimeBin),
            Iat =< BlacklistTime;
        {error, _} ->
            %% Redis down — fail open (allow request)
            false
    end.

-module(aurix_app).
-behaviour(application).

-export([start/2, stop/1]).
-export([apply_env_overrides/0]).

%%====================================================================
%% application callbacks
%%====================================================================

start(_StartType, _StartArgs) ->
    ok = apply_env_overrides(),
    ok = setup_database(),
    aurix_sup:start_link().

stop(_State) ->
    ok.

%%====================================================================
%% env overrides
%%====================================================================

apply_env_overrides() ->
    %% JWT secret
    case os:getenv("JWT_SECRET") of
        false -> ok;
        JwtSecret -> application:set_env(aurix, jwt_secret, list_to_binary(JwtSecret))
    end,
    %% Port
    case os:getenv("PORT") of
        false -> ok;
        PortStr -> application:set_env(aurix, port, list_to_integer(PortStr))
    end,
    %% CORS origin
    case os:getenv("CORS_ORIGIN") of
        false -> ok;
        Origin -> application:set_env(aurix, cors_origin, list_to_binary(Origin))
    end,
    %% Database config from DATABASE_URL or individual vars
    case os:getenv("DATABASE_URL") of
        false ->
            apply_db_env_vars();
        DbUrl ->
            case parse_database_url(DbUrl) of
                {ok, DbConfig} -> application:set_env(aurix, db, DbConfig);
                error -> ok
            end
    end,
    %% Redis config from REDIS_URL or individual vars
    case os:getenv("REDIS_URL") of
        false ->
            apply_redis_env_vars();
        RedisUrl ->
            case parse_redis_url(RedisUrl) of
                {ok, RedisConfig} -> application:set_env(aurix, redis, RedisConfig);
                error -> ok
            end
    end,
    ok.

apply_db_env_vars() ->
    {ok, CurrentDb} = application:get_env(aurix, db),
    Db1 = maybe_override(CurrentDb, "DB_HOST", host),
    Db2 = maybe_override(Db1, "DB_PORT", port, fun list_to_integer/1),
    Db3 = maybe_override(Db2, "DB_NAME", database),
    Db4 = maybe_override(Db3, "DB_USER", username),
    Db5 = maybe_override(Db4, "DB_PASSWORD", password),
    application:set_env(aurix, db, Db5).

apply_redis_env_vars() ->
    {ok, CurrentRedis} = application:get_env(aurix, redis),
    R1 = maybe_override(CurrentRedis, "REDIS_HOST", host),
    R2 = maybe_override(R1, "REDIS_PORT", port, fun list_to_integer/1),
    application:set_env(aurix, redis, R2).

maybe_override(Config, EnvVar, Key) ->
    maybe_override(Config, EnvVar, Key, fun(V) -> V end).

maybe_override(Config, EnvVar, Key, Transform) ->
    case os:getenv(EnvVar) of
        false -> Config;
        Val -> lists:keystore(Key, 1, Config, {Key, Transform(Val)})
    end.

%% Parse postgres://user:pass@host:port/dbname
parse_database_url(Url) ->
    try
        Rest = case lists:prefix("postgres://", Url) of
            true -> lists:nthtail(11, Url);
            false ->
                case lists:prefix("postgresql://", Url) of
                    true -> lists:nthtail(13, Url);
                    false -> throw(bad_scheme)
                end
        end,
        {UserPass, HostPortDb} = case string:split(Rest, "@") of
            [UP, HPD] -> {UP, HPD};
            _ -> throw(bad_format)
        end,
        {User, Pass} = case string:split(UserPass, ":") of
            [U, P] -> {U, P};
            [U] -> {U, ""}
        end,
        {HostPort, Db} = case string:split(HostPortDb, "/") of
            [HP, D] -> {HP, D};
            _ -> throw(bad_format)
        end,
        {Host, Port} = case string:split(HostPort, ":") of
            [H, P2] -> {H, list_to_integer(P2)};
            [H] -> {H, 5432}
        end,
        {ok, [{host, Host}, {port, Port}, {database, Db},
              {username, User}, {password, Pass}]}
    catch
        _:_ -> error
    end.

%% Parse redis://host:port or redis://:password@host:port
parse_redis_url(Url) ->
    try
        Rest = case lists:prefix("redis://", Url) of
            true -> lists:nthtail(8, Url);
            false -> throw(bad_scheme)
        end,
        HostPort = case string:split(Rest, "@") of
            [_, HP] -> HP;
            [HP] -> HP
        end,
        {Host, Port} = case string:split(HostPort, ":") of
            [H, P] -> {H, list_to_integer(P)};
            [H] -> {H, 6379}
        end,
        {ok, [{host, Host}, {port, Port}]}
    catch
        _:_ -> error
    end.

%%====================================================================
%% internal
%%====================================================================

setup_database() ->
    {ok, DbConfig} = application:get_env(aurix, db),
    Host = proplists:get_value(host, DbConfig, "localhost"),
    Port = proplists:get_value(port, DbConfig, 5432),
    Database = proplists:get_value(database, DbConfig, "aurix_dev"),
    Username = proplists:get_value(username, DbConfig, "aurix"),
    Password = proplists:get_value(password, DbConfig, "aurix_dev_pass"),
    pgapp:connect([
        {host, Host},
        {port, Port},
        {database, Database},
        {username, Username},
        {password, Password},
        {size, 10}
    ]).



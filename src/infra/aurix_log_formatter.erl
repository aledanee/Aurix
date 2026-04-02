-module(aurix_log_formatter).

-export([format/2]).

%% OTP logger formatter callback
-spec format(logger:log_event(), logger:formatter_config()) -> unicode:chardata().
format(#{level := Level, msg := Msg, meta := Meta}, _Config) ->
    Timestamp = format_timestamp(maps:get(time, Meta, erlang:system_time(microsecond))),
    %% Get process-level logger metadata (request_id, tenant_id, user_id)
    ProcessMeta = maps:with([request_id, tenant_id, user_id], Meta),
    Base = #{
        <<"timestamp">> => Timestamp,
        <<"level">> => atom_to_binary(Level)
    },
    MsgMap = extract_msg(Msg),
    %% Merge: base fields first, then process metadata, then message fields
    %% Message fields take priority (they're most specific)
    Merged = maps:merge(maps:merge(Base, encode_meta(ProcessMeta)), encode_map(MsgMap)),
    [jsx:encode(Merged), $\n].

%% Extract the message payload
extract_msg({report, Report}) when is_map(Report) ->
    Report;
extract_msg({string, String}) ->
    #{msg => iolist_to_binary(String)};
extract_msg({Format, Args}) ->
    #{msg => iolist_to_binary(io_lib:format(Format, Args))}.

%% Convert atom keys and non-binary values for JSON encoding
encode_map(Map) when is_map(Map) ->
    maps:fold(fun(K, V, Acc) ->
        Key = to_binary_key(K),
        Val = to_json_safe(V),
        maps:put(Key, Val, Acc)
    end, #{}, Map).

encode_meta(Map) ->
    maps:fold(fun(K, V, Acc) ->
        maps:put(atom_to_binary(K), to_json_safe(V), Acc)
    end, #{}, Map).

to_binary_key(K) when is_atom(K) -> atom_to_binary(K);
to_binary_key(K) when is_binary(K) -> K;
to_binary_key(K) -> iolist_to_binary(io_lib:format("~p", [K])).

to_json_safe(V) when is_binary(V) -> V;
to_json_safe(V) when is_atom(V) -> atom_to_binary(V);
to_json_safe(V) when is_integer(V) -> V;
to_json_safe(V) when is_float(V) -> V;
to_json_safe(V) when is_list(V) ->
    try iolist_to_binary(V)
    catch _:_ -> iolist_to_binary(io_lib:format("~p", [V]))
    end;
to_json_safe(V) when is_map(V) -> encode_map(V);
to_json_safe(V) when is_pid(V) -> list_to_binary(pid_to_list(V));
to_json_safe(V) -> iolist_to_binary(io_lib:format("~p", [V])).

format_timestamp(TimeMicro) ->
    TimeSec = TimeMicro div 1000000,
    Millis = (TimeMicro rem 1000000) div 1000,
    {{Y, Mo, D}, {H, Mi, S}} = calendar:system_time_to_universal_time(TimeSec, second),
    iolist_to_binary(io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0B.~3..0BZ",
                                    [Y, Mo, D, H, Mi, S, Millis])).

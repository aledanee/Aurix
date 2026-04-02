---
name: erlang-otp-patterns
description: "Erlang/OTP patterns and conventions for Aurix. Use when: writing gen_servers, supervisors, application modules, behaviour implementations, or OTP process management. Covers supervision strategies, gen_server callbacks, error handling, and Aurix-specific module conventions."
---

# Erlang/OTP Patterns for Aurix

## When to Use
- Creating new OTP modules (gen_server, supervisor, application)
- Implementing behaviours and callbacks
- Setting up supervision trees
- Writing process-based services

## Supervision Tree Structure

```
aurix_sup (one_for_one, intensity 5/60s)
├── aurix_db_pool (worker pool)
├── aurix_redis_pool (eredis pool)
├── aurix_http_sup (supervisor → Cowboy listener)
├── aurix_price_provider (gen_server)
├── aurix_outbox_dispatcher (gen_server)
├── aurix_etl_scheduler (gen_server)
└── aurix_rate_limiter (gen_server)
```

### Child Spec Template

```erlang
child_spec() ->
    #{
        id => ?MODULE,
        start => {?MODULE, start_link, []},
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [?MODULE]
    }.
```

## gen_server Template

```erlang
-module(aurix_example_server).
-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {}).

%%% API %%%

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%% Callbacks %%%

init([]) ->
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.
```

## Application Module Template

```erlang
-module(aurix_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    aurix_sup:start_link().

stop(_State) ->
    ok.
```

## Error Handling Conventions

- Return tagged tuples: `{ok, Result}` or `{error, Reason}`
- Reason atoms: `not_found`, `already_exists`, `insufficient_balance`, `insufficient_gold`, `invalid_credentials`, `tenant_inactive`, `account_disabled`
- Let processes crash on unexpected errors — the supervisor restarts them
- Log errors with `logger:error/2` before returning error tuples for expected failures

## Process Communication

- Use `gen_server:call/2` for synchronous requests with default 5s timeout
- Use `gen_server:cast/2` for fire-and-forget operations
- Use `self() ! message` or `erlang:send_after/3` for periodic work (ETL, outbox polling)

## Periodic Work Pattern (for ETL/Outbox)

```erlang
init([]) ->
    schedule_tick(),
    {ok, #state{}}.

handle_info(tick, State) ->
    NewState = do_work(State),
    schedule_tick(),
    {noreply, NewState};

schedule_tick() ->
    erlang:send_after(?INTERVAL_MS, self(), tick).
```

## Module Naming Quick Reference

| Type | Pattern | Example |
|------|---------|---------|
| Application | `aurix_app` | `aurix_app` |
| Supervisor | `aurix_*_sup` | `aurix_sup`, `aurix_http_sup` |
| Service | `aurix_*_service` | `aurix_auth_service` |
| Repository | `aurix_repo_*` | `aurix_repo_user` |
| Handler | `aurix_*_handler` | `aurix_auth_handler` |
| GenServer | descriptive name | `aurix_price_provider` |

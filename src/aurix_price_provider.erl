-module(aurix_price_provider).
-behaviour(gen_server).

-export([start_link/0, get_price/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    price_eur_cents :: integer()
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec get_price() -> {ok, PriceEurCents :: integer()}.
get_price() ->
    gen_server:call(?MODULE, get_price).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    PriceStr = os:getenv("GOLD_PRICE_EUR", "65.00"),
    PriceCents = parse_price_to_cents(PriceStr),
    {ok, #state{price_eur_cents = PriceCents}}.

handle_call(get_price, _From, #state{price_eur_cents = PriceCents} = State) ->
    {reply, {ok, PriceCents}, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================

-spec parse_price_to_cents(string()) -> integer().
parse_price_to_cents(Str) ->
    Float = list_to_float(ensure_decimal(Str)),
    round(Float * 100).

-spec ensure_decimal(string()) -> string().
ensure_decimal(Str) ->
    case lists:member($., Str) of
        true -> Str;
        false -> Str ++ ".0"
    end.

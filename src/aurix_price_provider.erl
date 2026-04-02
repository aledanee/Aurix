-module(aurix_price_provider).
-behaviour(gen_server).

-export([start_link/0, get_price/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    price_eur_per_gram :: number()
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec get_price() -> {ok, number()}.
get_price() ->
    gen_server:call(?MODULE, get_price).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    PriceStr = os:getenv("GOLD_PRICE_EUR", "65.00"),
    Price = list_to_float(PriceStr),
    {ok, #state{price_eur_per_gram = Price}}.

handle_call(get_price, _From, #state{price_eur_per_gram = Price} = State) ->
    {reply, {ok, Price}, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

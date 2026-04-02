-module(aurix_admin_service).

-export([list_tenants/0, deactivate_tenant/1, update_gold_price/1,
         update_fee_config/4, trigger_etl/0]).

%% US-4.2 — List all tenants
-spec list_tenants() -> {ok, [map()]}.
list_tenants() ->
    aurix_repo_tenant:list_all().

%% US-4.3 — Deactivate a tenant
-spec deactivate_tenant(TenantId :: binary()) -> ok | {error, not_found}.
deactivate_tenant(TenantId) ->
    case aurix_repo_tenant:update_status(TenantId, <<"inactive">>) of
        ok ->
            logger:info(#{action => <<"admin.deactivate_tenant">>, tenant_id => TenantId}),
            ok;
        {error, not_found} ->
            {error, not_found}
    end.

%% US-4.5 — Update gold price
-spec update_gold_price(PriceEur :: binary()) -> ok | {error, invalid_price}.
update_gold_price(PriceEur) ->
    try
        PriceFloat = binary_to_float(ensure_decimal(PriceEur)),
        case PriceFloat > 0 of
            true ->
                PriceCents = round(PriceFloat * 100),
                aurix_price_provider:set_price(PriceCents),
                logger:info(#{action => <<"admin.update_gold_price">>, price_eur => PriceEur, price_cents => PriceCents}),
                ok;
            false ->
                {error, invalid_price}
        end
    catch _:_ ->
        {error, invalid_price}
    end.

%% US-4.6 — Update tenant fee configuration
-spec update_fee_config(TenantId :: binary(), BuyFeeRate :: binary(), SellFeeRate :: binary(), MinFeeEurCents :: integer()) -> ok | {error, invalid_params}.
update_fee_config(TenantId, BuyFeeRate, SellFeeRate, MinFeeEurCents) ->
    try
        BuyFloat = binary_to_float(ensure_decimal(BuyFeeRate)),
        SellFloat = binary_to_float(ensure_decimal(SellFeeRate)),
        case BuyFloat > 0 andalso SellFloat > 0 andalso is_integer(MinFeeEurCents) andalso MinFeeEurCents >= 0 of
            true ->
                aurix_repo_fee_config:upsert(TenantId, BuyFeeRate, SellFeeRate, MinFeeEurCents),
                logger:info(#{action => <<"admin.update_fee_config">>, tenant_id => TenantId, buy_fee_rate => BuyFeeRate, sell_fee_rate => SellFeeRate, min_fee_eur_cents => MinFeeEurCents}),
                ok;
            false ->
                {error, invalid_params}
        end
    catch _:_ ->
        {error, invalid_params}
    end.

%% US-4.7 — Trigger ETL manually
-spec trigger_etl() -> ok.
trigger_etl() ->
    aurix_etl_scheduler:run_now(),
    logger:info(#{action => <<"admin.trigger_etl">>}),
    ok.

%% Internal
ensure_decimal(Bin) ->
    case binary:match(Bin, <<".">>) of
        nomatch -> <<Bin/binary, ".0">>;
        _ -> Bin
    end.

-module(aurix_repo_fee_config).

-export([get_by_tenant_id/1]).

%% Gets the fee configuration for a tenant.
-spec get_by_tenant_id(TenantId :: binary()) -> {ok, map()} | {error, not_found}.
get_by_tenant_id(TenantId) ->
    SQL = "SELECT id, tenant_id, buy_fee_rate, sell_fee_rate, min_fee_eur_cents "
          "FROM tenant_fee_config WHERE tenant_id = $1",
    case pgapp:equery(SQL, [TenantId]) of
        {ok, _Cols, [Row]} ->
            {ok, fee_config_row_to_map(Row)};
        {ok, _Cols, []} ->
            {error, not_found}
    end.

%% Internal
%% Note: PostgreSQL numeric(10,6) values come from epgsql as floats or binary strings.
%% buy_fee_rate and sell_fee_rate are small decimals like 0.005000
fee_config_row_to_map({Id, TenantId, BuyFeeRate, SellFeeRate, MinFeeCents}) ->
    #{
        id => Id,
        tenant_id => TenantId,
        buy_fee_rate => BuyFeeRate,
        sell_fee_rate => SellFeeRate,
        min_fee_eur_cents => MinFeeCents
    }.

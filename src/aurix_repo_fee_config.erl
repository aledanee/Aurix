-module(aurix_repo_fee_config).

-export([get_by_tenant_id/1]).

%% Gets the fee configuration for a tenant.
%% Returns default values if no override exists for the tenant.
-spec get_by_tenant_id(TenantId :: binary()) -> {ok, map()}.
get_by_tenant_id(TenantId) ->
    SQL = "SELECT id, tenant_id, buy_fee_rate, sell_fee_rate, min_fee_eur_cents "
          "FROM tenant_fee_config WHERE tenant_id = $1",
    case pgapp:equery(SQL, [TenantId]) of
        {ok, _Cols, [Row]} ->
            {ok, fee_config_row_to_map(Row)};
        {ok, _Cols, []} ->
            {ok, default_fee_config(TenantId)}
    end.

default_fee_config(TenantId) ->
    #{
        id => undefined,
        tenant_id => TenantId,
        buy_fee_rate => <<"0.005000">>,
        sell_fee_rate => <<"0.005000">>,
        min_fee_eur_cents => 50
    }.

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

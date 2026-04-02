-module(aurix_repo_wallet).

-export([create/3, get_by_user_id/2]).

%% Creates a wallet for a new user with seeded EUR balance (10,000.00 = 1000000 cents).
-spec create(TenantId :: binary(), UserId :: binary(), WalletId :: binary()) ->
    {ok, binary()}.
create(TenantId, UserId, WalletId) ->
    SQL = "INSERT INTO wallets (id, tenant_id, user_id, gold_balance_grams, fiat_balance_eur_cents, version, created_at, updated_at) "
          "VALUES ($1, $2, $3, 0, 1000000, 1, now(), now())",
    {ok, 1} = pgapp:equery(SQL, [WalletId, TenantId, UserId]),
    {ok, WalletId}.

%% Gets the wallet for a user within a tenant.
-spec get_by_user_id(TenantId :: binary(), UserId :: binary()) ->
    {ok, map()} | {error, not_found}.
get_by_user_id(TenantId, UserId) ->
    SQL = "SELECT id, tenant_id, user_id, gold_balance_grams, fiat_balance_eur_cents, version, created_at, updated_at "
          "FROM wallets WHERE tenant_id = $1 AND user_id = $2",
    case pgapp:equery(SQL, [TenantId, UserId]) of
        {ok, _Cols, [Row]} ->
            {ok, wallet_row_to_map(Row)};
        {ok, _Cols, []} ->
            {error, not_found}
    end.

%% Internal
wallet_row_to_map({Id, TenantId, UserId, GoldGrams, FiatCents, Version, CreatedAt, UpdatedAt}) ->
    #{
        id => Id,
        tenant_id => TenantId,
        user_id => UserId,
        gold_balance_grams => GoldGrams,
        fiat_balance_eur_cents => FiatCents,
        version => Version,
        created_at => CreatedAt,
        updated_at => UpdatedAt
    }.

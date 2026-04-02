-module(aurix_router).

-export([dispatch/0]).

%%====================================================================
%% API
%%====================================================================

-spec dispatch() -> cowboy_router:dispatch_rules().
dispatch() ->
    cowboy_router:compile([
        {'_', routes()}
    ]).

%%====================================================================
%% internal
%%====================================================================

routes() ->
    [
        %% Health
        {"/health", aurix_health_handler, #{}},

        %% Swagger
        {"/swagger", aurix_swagger_handler, #{action => ui}},
        {"/swagger/spec", aurix_swagger_handler, #{action => spec}},

        %% Auth (public)
        {"/auth/register", aurix_auth_handler, #{action => register}},
        {"/auth/login", aurix_auth_handler, #{action => login}},
        {"/auth/refresh", aurix_auth_handler, #{action => refresh}},

        %% Auth (protected)
        {"/auth/logout", aurix_auth_handler, #{action => logout}},
        {"/auth/change-password", aurix_auth_handler, #{action => change_password}},

        %% Wallet (protected)
        {"/wallet", aurix_wallet_handler, #{action => view}},
        {"/wallet/buy", aurix_wallet_handler, #{action => buy}},
        {"/wallet/sell", aurix_wallet_handler, #{action => sell}},

        %% Transactions (protected)
        {"/transactions", aurix_transaction_handler, #{}},

        %% Insights (protected)
        {"/insights", aurix_insight_handler, #{}},

        %% Privacy (protected)
        {"/privacy/export", aurix_privacy_handler, #{action => export}},
        {"/privacy/erasure-request", aurix_privacy_handler, #{action => erasure}},

        %% Admin (protected, role=admin)
        {"/admin/tenants", aurix_admin_handler, #{action => list_tenants}},
        {"/admin/tenants/:tenant_id/deactivate", aurix_admin_handler, #{action => deactivate_tenant}},
        {"/admin/gold-price", aurix_admin_handler, #{action => update_gold_price}}
    ].

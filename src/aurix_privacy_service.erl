-module(aurix_privacy_service).

-export([request_erasure/2]).

%% Process an erasure request: disable account, revoke tokens, blacklist JWT.
-spec request_erasure(TenantId :: binary(), UserId :: binary()) -> ok | {error, term()}.
request_erasure(TenantId, UserId) ->
    %% 1. Soft-delete the user account
    case aurix_repo_user:soft_delete(TenantId, UserId) of
        ok ->
            %% 2. Revoke all refresh tokens
            ok = aurix_repo_refresh_token:revoke_all_for_user(TenantId, UserId),
            %% 3. Blacklist current access token(s) via JWT blacklist
            ok = aurix_jwt_blacklist:blacklist_user(UserId),
            logger:info(#{action => <<"privacy.erasure_complete">>, user_id => UserId, tenant_id => TenantId}),
            ok;
        {error, not_found} ->
            {error, not_found}
    end.

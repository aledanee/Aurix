-module(aurix_transaction_service).

-export([list_transactions/4]).

%% List transactions for a user with cursor-based pagination.
%% Opts: #{limit => integer(), type => binary() | undefined}
-spec list_transactions(TenantId :: binary(), UserId :: binary(),
                         CursorParam :: binary() | undefined,
                         Opts :: map()) -> {ok, [map()], NextCursor :: binary() | null}.
list_transactions(TenantId, UserId, CursorParam, Opts) ->
    Cursor = case CursorParam of
        undefined -> undefined;
        CursorBin ->
            case aurix_repo_transaction:decode_cursor(CursorBin) of
                {ok, C} -> C;
                {error, _} -> undefined
            end
    end,
    aurix_repo_transaction:list_by_user(TenantId, UserId, Cursor, Opts).

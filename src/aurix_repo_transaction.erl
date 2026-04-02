-module(aurix_repo_transaction).

-export([insert/1, insert/2, list_by_user/4, check_idempotency/2, decode_cursor/1]).

%% Insert a new transaction record (append-only ledger).
%% TxnMap is a map with all required fields.
-spec insert(TxnMap :: map()) -> {ok, binary()}.
insert(TxnMap) ->
    SQL = "INSERT INTO transactions "
          "(id, tenant_id, wallet_id, user_id, type, gold_grams, price_eur_per_gram, "
          "gross_eur_cents, fee_eur_cents, status, idempotency_key, metadata, created_at) "
          "VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'posted', $10, $11, now())",
    #{
        id := Id,
        tenant_id := TenantId,
        wallet_id := WalletId,
        user_id := UserId,
        type := Type,
        gold_grams := GoldGrams,
        price_eur_per_gram := PricePerGram,
        gross_eur_cents := GrossEurCents,
        fee_eur_cents := FeeEurCents,
        idempotency_key := IdempotencyKey
    } = TxnMap,
    Metadata = maps:get(metadata, TxnMap, null),
    {ok, 1} = pgapp:equery(SQL, [
        Id, TenantId, WalletId, UserId, Type,
        GoldGrams, PricePerGram, GrossEurCents, FeeEurCents,
        IdempotencyKey, Metadata
    ]),
    {ok, Id}.

%% Insert a ledger entry within an existing DB transaction (takes a Conn pid).
-spec insert(pid(), map()) -> {ok, binary()}.
insert(Conn, TxnMap) ->
    SQL = "INSERT INTO transactions "
          "(id, tenant_id, wallet_id, user_id, type, gold_grams, price_eur_per_gram, "
          "gross_eur_cents, fee_eur_cents, status, idempotency_key, metadata, created_at) "
          "VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'posted', $10, $11, now())",
    #{
        id := Id,
        tenant_id := TenantId,
        wallet_id := WalletId,
        user_id := UserId,
        type := Type,
        gold_grams := GoldGrams,
        price_eur_per_gram := PricePerGram,
        gross_eur_cents := GrossEurCents,
        fee_eur_cents := FeeEurCents,
        idempotency_key := IdempotencyKey
    } = TxnMap,
    Metadata = maps:get(metadata, TxnMap, null),
    {ok, 1} = epgsql:equery(Conn, SQL, [
        Id, TenantId, WalletId, UserId, Type,
        GoldGrams, PricePerGram, GrossEurCents, FeeEurCents,
        IdempotencyKey, Metadata
    ]),
    {ok, Id}.

%% Check if an idempotency key has been used. Returns existing transaction if found.
-spec check_idempotency(TenantId :: binary(), IdempotencyKey :: binary()) ->
    {ok, map()} | {error, not_found}.
check_idempotency(TenantId, IdempotencyKey) ->
    SQL = "SELECT id, tenant_id, wallet_id, user_id, type, gold_grams, price_eur_per_gram, "
          "gross_eur_cents, fee_eur_cents, status, idempotency_key, created_at "
          "FROM transactions WHERE tenant_id = $1 AND idempotency_key = $2",
    case pgapp:equery(SQL, [TenantId, IdempotencyKey]) of
        {ok, _Cols, [Row]} ->
            {ok, txn_row_to_map(Row)};
        {ok, _Cols, []} ->
            {error, not_found}
    end.

%% List transactions for a user with cursor-based pagination.
%% Cursor is either `undefined` (first page) or `{CreatedAt, Id}` for subsequent pages.
%% Optional TypeFilter: `undefined`, `<<"buy">>`, or `<<"sell">>`.
-spec list_by_user(TenantId :: binary(), UserId :: binary(),
                   Cursor :: undefined | {binary(), binary()},
                   Opts :: map()) -> {ok, [map()], NextCursor :: binary() | null}.
list_by_user(TenantId, UserId, Cursor, Opts) ->
    Limit = maps:get(limit, Opts, 20),
    TypeFilter = maps:get(type, Opts, undefined),
    FetchLimit = Limit + 1,
    {SQL, Params} = build_list_query(TenantId, UserId, Cursor, TypeFilter, FetchLimit),
    {ok, _Cols, Rows} = pgapp:equery(SQL, Params),
    Items = [txn_row_to_map(Row) || Row <- Rows],
    case length(Items) > Limit of
        true ->
            PageItems = lists:sublist(Items, Limit),
            LastItem = lists:last(PageItems),
            NextCursor = encode_cursor(maps:get(created_at, LastItem), maps:get(id, LastItem)),
            {ok, PageItems, NextCursor};
        false ->
            {ok, Items, null}
    end.

%% Decodes a pagination cursor. Returns {ok, {CreatedAt, Id}} or {error, invalid_cursor}.
-spec decode_cursor(binary()) -> {ok, {binary(), binary()}} | {error, invalid_cursor}.
decode_cursor(Cursor) ->
    try
        JSON = base64:decode(Cursor),
        #{<<"created_at">> := CreatedAt, <<"id">> := Id} = jsx:decode(JSON, [return_maps]),
        {ok, {CreatedAt, Id}}
    catch
        _:_ -> {error, invalid_cursor}
    end.

%% Internal

build_list_query(TenantId, UserId, undefined, undefined, Limit) ->
    SQL = "SELECT id, tenant_id, wallet_id, user_id, type, gold_grams, price_eur_per_gram, "
          "gross_eur_cents, fee_eur_cents, status, idempotency_key, created_at "
          "FROM transactions WHERE tenant_id = $1 AND user_id = $2 "
          "ORDER BY created_at DESC, id DESC LIMIT $3",
    {SQL, [TenantId, UserId, Limit]};

build_list_query(TenantId, UserId, undefined, Type, Limit) ->
    SQL = "SELECT id, tenant_id, wallet_id, user_id, type, gold_grams, price_eur_per_gram, "
          "gross_eur_cents, fee_eur_cents, status, idempotency_key, created_at "
          "FROM transactions WHERE tenant_id = $1 AND user_id = $2 AND type = $3 "
          "ORDER BY created_at DESC, id DESC LIMIT $4",
    {SQL, [TenantId, UserId, Type, Limit]};

build_list_query(TenantId, UserId, {CursorCreatedAt, CursorId}, undefined, Limit) ->
    SQL = "SELECT id, tenant_id, wallet_id, user_id, type, gold_grams, price_eur_per_gram, "
          "gross_eur_cents, fee_eur_cents, status, idempotency_key, created_at "
          "FROM transactions WHERE tenant_id = $1 AND user_id = $2 "
          "AND (created_at, id) < ($3, $4) "
          "ORDER BY created_at DESC, id DESC LIMIT $5",
    {SQL, [TenantId, UserId, CursorCreatedAt, CursorId, Limit]};

build_list_query(TenantId, UserId, {CursorCreatedAt, CursorId}, Type, Limit) ->
    SQL = "SELECT id, tenant_id, wallet_id, user_id, type, gold_grams, price_eur_per_gram, "
          "gross_eur_cents, fee_eur_cents, status, idempotency_key, created_at "
          "FROM transactions WHERE tenant_id = $1 AND user_id = $2 AND type = $3 "
          "AND (created_at, id) < ($4, $5) "
          "ORDER BY created_at DESC, id DESC LIMIT $6",
    {SQL, [TenantId, UserId, Type, CursorCreatedAt, CursorId, Limit]}.

txn_row_to_map({Id, TenantId, WalletId, UserId, Type, GoldGrams, PricePerGram,
                GrossEurCents, FeeEurCents, Status, IdempotencyKey, CreatedAt}) ->
    #{
        id => Id,
        tenant_id => TenantId,
        wallet_id => WalletId,
        user_id => UserId,
        type => Type,
        gold_grams => GoldGrams,
        price_eur_per_gram => PricePerGram,
        gross_eur_cents => GrossEurCents,
        fee_eur_cents => FeeEurCents,
        status => Status,
        idempotency_key => IdempotencyKey,
        created_at => CreatedAt
    }.

%% Cursor encoding: base64url(json({"created_at": "...", "id": "..."}))
encode_cursor(CreatedAt, Id) ->
    JSON = jsx:encode(#{<<"created_at">> => CreatedAt, <<"id">> => Id}),
    base64:encode(JSON).

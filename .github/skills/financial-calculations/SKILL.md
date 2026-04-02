---
name: financial-calculations
description: "Safe financial calculation patterns for Aurix. Use when: computing gold buy/sell amounts, EUR costs, fees, wallet balance updates, or any arithmetic involving money or gold quantities. Prevents floating-point errors in fintech operations."
---

# Financial Calculations for Aurix

## When to Use
- Computing buy/sell costs
- Calculating fees
- Updating wallet balances
- Formatting financial amounts for display
- Writing tests involving money

## Cardinal Rule

**NEVER use floating-point for money.** EUR is stored as `bigint` cents. Gold is `numeric(24,8)`.

## Data Types

| Value | Storage Type | Example | Meaning |
|-------|-------------|---------|---------|
| EUR amount | `bigint` (cents) | `1000000` | €10,000.00 |
| Gold amount | `numeric(24,8)` | `1.25000000` | 1.25 grams |
| Price per gram | `numeric(24,8)` | `65.00000000` | €65.00/gram |
| Fee rate | `numeric(10,6)` | `0.005000` | 0.5% |
| Min fee | `bigint` (cents) | `50` | €0.50 |

## Buy Gold Calculation

```
Input: grams (decimal), price_eur_per_gram (decimal)

1. gross_eur_cents = round(grams * price_eur_per_gram * 100)
2. fee_eur_cents = max(min_fee_eur_cents, round(gross_eur_cents * buy_fee_rate))
3. total_eur_cents = gross_eur_cents + fee_eur_cents
4. Validate: wallet.fiat_balance_eur_cents >= total_eur_cents
5. New fiat balance = wallet.fiat_balance_eur_cents - total_eur_cents
6. New gold balance = wallet.gold_balance_grams + grams
```

### Example
```
grams = 1.25
price = 65.00 EUR/gram
buy_fee_rate = 0.005 (0.5%)
min_fee = 50 cents (€0.50)

gross_eur_cents = round(1.25 * 65.00 * 100) = round(8125.0) = 8125
fee_eur_cents = max(50, round(8125 * 0.005)) = max(50, round(40.625)) = max(50, 41) = 50
total_eur_cents = 8125 + 50 = 8175

Wallet: debit 8175 cents, credit 1.25000000 grams
```

## Sell Gold Calculation

```
Input: grams (decimal), price_eur_per_gram (decimal)

1. gross_eur_cents = round(grams * price_eur_per_gram * 100)
2. fee_eur_cents = max(min_fee_eur_cents, round(gross_eur_cents * sell_fee_rate))
3. net_eur_cents = gross_eur_cents - fee_eur_cents
4. Validate: wallet.gold_balance_grams >= grams
5. New gold balance = wallet.gold_balance_grams - grams
6. New fiat balance = wallet.fiat_balance_eur_cents + net_eur_cents
```

## Erlang Implementation Notes

### Safe Integer Arithmetic in Erlang

Erlang integers are arbitrary precision — no overflow risk. Use integer arithmetic where possible:

```erlang
%% Computing gross EUR cents from grams and price
%% Both grams and price come from numeric(24,8) in PostgreSQL
%% which epgsql returns as strings or {decimal, ...} tuples

-spec compute_gross_eur_cents(Grams :: number(), PricePerGram :: number()) -> integer().
compute_gross_eur_cents(Grams, PricePerGram) ->
    %% round/1 on a float gives an integer in Erlang
    round(Grams * PricePerGram * 100).

-spec compute_fee(GrossEurCents :: integer(), FeeRate :: float(), MinFeeCents :: integer()) -> integer().
compute_fee(GrossEurCents, FeeRate, MinFeeCents) ->
    max(MinFeeCents, round(GrossEurCents * FeeRate)).
```

### PostgreSQL Numeric Handling

When receiving `numeric(24,8)` from epgsql:
- May arrive as binary string: `<<"1.25000000">>`
- Convert with `binary_to_float/1` or parse manually
- For computations, work in Erlang then store results back as parameterized values

## Wallet Update SQL

```sql
-- Buy: debit fiat, credit gold
UPDATE wallets
SET fiat_balance_eur_cents = fiat_balance_eur_cents - $3,
    gold_balance_grams = gold_balance_grams + $4,
    version = version + 1,
    updated_at = now()
WHERE tenant_id = $1 AND user_id = $2 AND version = $5;

-- Sell: debit gold, credit fiat
UPDATE wallets
SET gold_balance_grams = gold_balance_grams - $3,
    fiat_balance_eur_cents = fiat_balance_eur_cents + $4,
    version = version + 1,
    updated_at = now()
WHERE tenant_id = $1 AND user_id = $2 AND version = $5;
```

## Display Formatting

### EUR (from cents to display string)
```
1000000 cents → "€10,000.00"
8175 cents → "€81.75"
50 cents → "€0.50"
```

### Gold (from numeric to display string)
```
1.25000000 → "1.2500 g" (show 4 decimal places)
0.00100000 → "0.0010 g"
```

## Testing Financial Calculations

```erlang
%% Test with known values — compare integers, not floats
?assertEqual(8125, compute_gross_eur_cents(1.25, 65.0)),
?assertEqual(50, compute_fee(8125, 0.005, 50)),  %% min fee applies
?assertEqual(41, compute_fee(8125, 0.005, 40)),   %% computed fee > min fee

%% Edge cases
?assertEqual(0, compute_gross_eur_cents(0, 65.0)),
?assertEqual(1, compute_gross_eur_cents(0.001, 10.0)),  %% round(0.001 * 10.0 * 100) = 1
```

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Fix |
|---|---|---|
| `Price = 65.0, Cost = Grams * Price` (store as float) | Float rounding errors accumulate | Compute in cents, store as bigint |
| `fiat_balance = 100.50` in DB | Float column for money | Use bigint cents: `10050` |
| `gold_grams FLOAT` in DB | Float for precision amounts | Use `numeric(24,8)` |
| Displaying cents without formatting | User sees `8175` instead of `€81.75` | Divide by 100 at display layer only |

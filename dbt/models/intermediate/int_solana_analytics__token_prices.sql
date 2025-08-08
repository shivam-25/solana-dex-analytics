{{ config(
    materialized='materialized_view',
    engine='AggregatingMergeTree()',
    order_by=['token_mint'],
    populate=true,
    description='Token best price by highest liquidity market'
) }}

SELECT 
    assumeNotNull(other_mint) AS token_mint,
    argMaxState(market, total_liquidity) AS best_market_state,
    argMaxState(price_in_anchor, total_liquidity) AS price_anchor_state,
    maxState(total_liquidity) AS max_liquidity_state,
    argMaxState(sol_usd_price, total_liquidity) AS sol_usd_price_state,
    max(block_timestamp) AS last_updated
FROM {{ ref('stg_solana_analytics__trades') }}
WHERE other_mint IS NOT NULL
GROUP BY token_mint
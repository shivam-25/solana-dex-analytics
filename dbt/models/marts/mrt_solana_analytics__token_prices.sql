{{ config(
    materialized='view',
    description='Token prices from best liquidity market for API consumption'
) }}

WITH merged_data AS (
    SELECT 
        token_mint,
        argMaxMerge(best_market_state) AS best_market,
        argMaxMerge(price_anchor_state) AS price_in_anchor,
        maxMerge(max_liquidity_state) AS max_liquidity,
        argMaxMerge(sol_usd_price_state) AS sol_usd_price,
        last_updated
    FROM {{ ref('int_solana_analytics__token_prices') }}
    GROUP BY token_mint, last_updated
)
SELECT 
    token_mint,
    best_market,
    price_in_anchor,
    max_liquidity,
    sol_usd_price,
    last_updated,
    
    price_in_anchor AS price_sol,
    
    price_in_anchor * sol_usd_price AS price_usd,
    
    max_liquidity * price_in_anchor AS market_cap_sol,
    max_liquidity * price_in_anchor * sol_usd_price AS market_cap_usd
    
FROM merged_data
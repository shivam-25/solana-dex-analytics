{{ config(
    materialized='view'
) }}

SELECT 
    market,
    CASE 
        WHEN source_mint = 'So11111111111111111111111111111111111111112' THEN destination_mint
        ELSE source_mint
    END AS mint,
    'So11111111111111111111111111111111111111112' AS anchor_mint,
    last_price_a_in_b AS price_sol,
    last_price_a_in_b * last_sol_usd_price AS price_usd,
    total_liquidity * last_sol_usd_price AS total_liquidity_usd,
    total_liquidity / 2 AS total_token_supply_a,  -- Approximation
    total_liquidity / 2 AS total_token_supply_b,  -- Approximation
    source_mint,
    destination_mint,
    CASE 
        WHEN source_mint = 'So11111111111111111111111111111111111111112' THEN destination_mint
        ELSE source_mint
    END AS other_mint,
    block_timestamp
FROM {{ source('solana_analytics', 'mv_market_latest') }}
WHERE last_price_a_in_b > 0
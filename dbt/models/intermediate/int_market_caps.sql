{{ config(
    materialized='view',
    post_hook=[]
) }}

SELECT 
    market,
    mint,
    anchor_mint,
    price_sol,
    price_usd,
    total_liquidity_usd,
    
    -- Single place for token supply determination
    CASE 
        WHEN source_mint = mint THEN total_token_supply_a
        ELSE total_token_supply_b
    END AS token_supply,
    
    -- Centralized market cap calculation
    CASE 
        WHEN source_mint = mint THEN total_token_supply_a * price_sol
        ELSE total_token_supply_b * price_sol
    END AS market_cap_sol,
    
    CASE 
        WHEN source_mint = mint THEN total_token_supply_a * price_usd
        ELSE total_token_supply_b * price_usd
    END AS market_cap_usd,
    
    block_timestamp
FROM {{ ref('int_latest_market_prices') }}
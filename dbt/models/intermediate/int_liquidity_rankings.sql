{{ config(
    materialized='incremental',
    engine='ReplacingMergeTree(last_updated)',
    order_by=['mint'],
    unique_key='mint',
    partition_by='toYYYYMM(last_updated)',
    pre_hook=[
        "SET optimize_aggregation_in_order = 1",
        "SET optimize_group_by_function_keys = 1"
    ]
) }}

WITH market_aggregates AS (
    SELECT 
        coalesce(mint, '') AS mint,
        market,
        anchor_mint,
        
        -- Use argMax to get values at max liquidity point
        argMax(price_sol, total_liquidity_usd) AS price_sol,
        argMax(price_usd, total_liquidity_usd) AS price_usd,
        argMax(market_cap_sol, total_liquidity_usd) AS market_cap_sol,
        argMax(market_cap_usd, total_liquidity_usd) AS market_cap_usd,
        argMax(token_supply, total_liquidity_usd) AS token_supply,
        
        -- Get the market with highest liquidity
        argMax(market, total_liquidity_usd) AS best_market,
        max(total_liquidity_usd) AS max_liquidity,
        max(block_timestamp) AS last_updated
        
    FROM {{ ref('int_market_caps') }}
    
    {% if is_incremental() %}
    WHERE block_timestamp > (
        SELECT max(last_updated) 
        FROM {{ this }}
    )
    {% endif %}
    
    GROUP BY mint, market, anchor_mint
)

SELECT 
    mint,
    argMax(best_market, max_liquidity) AS market,
    argMax(anchor_mint, max_liquidity) AS anchor_mint,
    argMax(price_sol, max_liquidity) AS price_sol,
    argMax(price_usd, max_liquidity) AS price_usd,
    argMax(market_cap_sol, max_liquidity) AS market_cap_sol,
    argMax(market_cap_usd, max_liquidity) AS market_cap_usd,
    max(max_liquidity) AS total_liquidity_usd,
    argMax(token_supply, max_liquidity) AS token_supply,
    max(last_updated) AS last_updated
FROM market_aggregates
GROUP BY mint
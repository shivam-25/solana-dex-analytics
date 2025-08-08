{{ config(
    materialized='view',
    description='Real-time market prices for API consumption'
) }}

SELECT 
    market,
    argMaxMerge(source_mint_state) AS source_mint,
    argMaxMerge(destination_mint_state) AS destination_mint,
    argMaxMerge(last_price_a_in_b_state) AS price_a_in_b,
    argMaxMerge(last_price_b_in_a_state) AS price_b_in_a,
    argMaxMerge(last_sol_usd_price_state) AS sol_usd_price,
    argMaxMerge(total_liquidity_state) AS total_liquidity,
    last_updated,
    
    CASE 
        WHEN destination_mint = {{ wsol() }} THEN price_a_in_b
        WHEN source_mint = {{ wsol() }} THEN price_b_in_a
        ELSE 0
    END AS price_sol,
    
    CASE 
        WHEN destination_mint = {{ wsol() }} THEN price_a_in_b * sol_usd_price
        WHEN source_mint = {{ wsol() }} THEN price_b_in_a * sol_usd_price
        WHEN source_mint IN ({{ usdc() }}, {{ usdt() }}) THEN price_a_in_b
        WHEN destination_mint IN ({{ usdc() }}, {{ usdt() }}) THEN price_b_in_a
        ELSE 0
    END AS price_usd,
    
    total_liquidity * price_sol AS market_cap_sol,
    total_liquidity * price_usd AS market_cap_usd

FROM {{ ref('int_solana_analytics__market_prices') }}
GROUP BY market, last_updated
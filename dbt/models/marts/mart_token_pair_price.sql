{{ config(
    materialized='view'
) }}

WITH token_pairs AS (
    SELECT 
        CASE 
            WHEN anchor_mint < mint THEN anchor_mint 
            ELSE mint 
        END AS mint_a,
        CASE 
            WHEN anchor_mint < mint THEN mint 
            ELSE anchor_mint 
        END AS mint_b,
        mint,  -- The non-anchor token
        market,  -- Already highest liquidity from int_liquidity_rankings
        price_sol,
        price_usd,
        market_cap_sol,
        market_cap_usd,
        last_updated
    FROM {{ ref('int_liquidity_rankings') }}
    FINAL
)

SELECT 
    mint,
    market,
    mint_a,
    mint_b,
    toString(price_sol) AS priceSol,
    toString(price_usd) AS priceUsd,
    toString(market_cap_sol) AS marketCapSol,
    toString(market_cap_usd) AS marketCapUsd,
    last_updated
FROM token_pairs
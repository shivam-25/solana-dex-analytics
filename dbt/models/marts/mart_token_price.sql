{{ config(
    materialized='view'
) }}

SELECT 
    mint,
    market,
    toString(price_sol) AS priceSol,
    toString(price_usd) AS priceUsd,
    toString(market_cap_sol) AS marketCapSol,
    toString(market_cap_usd) AS marketCapUsd,
    last_updated
FROM {{ ref('int_liquidity_rankings') }}
FINAL
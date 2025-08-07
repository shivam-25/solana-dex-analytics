SELECT 
    market,
    COUNT(*) as count
FROM {{ ref('mart_market_price') }}
GROUP BY market
HAVING COUNT(*) > 1
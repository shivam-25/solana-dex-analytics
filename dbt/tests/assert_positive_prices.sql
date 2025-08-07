SELECT *
FROM {{ ref('mart_token_price') }}
WHERE CAST(priceSol AS Float64) <= 0
   OR CAST(priceUsd AS Float64) <= 0
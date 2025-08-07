WITH trade_volumes AS (
    SELECT 
        trader,
        SUM(volume_sol) as calculated_vol_sol,
        SUM(volume_usd) as calculated_vol_usd
    FROM {{ ref('stg_trades') }}
    WHERE anchor_mint IS NOT NULL  -- Match filter in int_trader_aggregates
    GROUP BY trader
),
mart_volumes AS (
    SELECT 
        trader,
        CAST(volumeSol AS Float64) as mart_vol_sol,
        CAST(volumeUsd AS Float64) as mart_vol_usd
    FROM {{ ref('mart_trader_stats') }}
)
SELECT 
    t.trader,
    t.calculated_vol_sol,
    m.mart_vol_sol,
    ABS(t.calculated_vol_sol - m.mart_vol_sol) as diff
FROM trade_volumes t
JOIN mart_volumes m ON t.trader = m.trader
WHERE ABS(t.calculated_vol_sol - m.mart_vol_sol) > 0.01
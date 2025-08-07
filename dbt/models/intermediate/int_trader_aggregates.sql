{{ config(
    materialized='view',
    pre_hook=[
        "SET max_threads = 16"
    ]
) }}

WITH trader_base AS (
    -- Get real-time aggregates from MV
    SELECT 
        trader,
        trade_count,
        total_volume_sol,
        total_volume_usd,
        last_trade_time
    FROM {{ source('solana_analytics', 'mv_trader_volume') }}
),
trader_direction_split AS (
    -- Calculate buy/sell split from recent trades for direction analysis
    -- Only compute what MV doesn't provide
    SELECT 
        trader,
        countIf(trade_direction = 'buy') as buys,
        countIf(trade_direction = 'sell') as sells,
        sumIf(volume_sol, trade_direction = 'buy') as buy_volume_sol,
        sumIf(volume_sol, trade_direction = 'sell') as sell_volume_sol,
        sumIf(volume_usd, trade_direction = 'buy') as buy_volume_usd,
        sumIf(volume_usd, trade_direction = 'sell') as sell_volume_usd,
        avg(volume_sol) as avg_trade_size_sol,
        max(volume_sol) as max_trade_size_sol,
        min(volume_sol) as min_trade_size_sol,
        min(block_timestamp) as first_trade_timestamp
    FROM {{ ref('stg_trades') }}
    WHERE anchor_mint IS NOT NULL
      AND block_timestamp >= now() - INTERVAL 24 HOUR  -- Only recent for direction
    GROUP BY trader
)
SELECT 
    b.trader,
    -- Use MV aggregates as primary source
    b.trade_count as total_trades_state,
    b.total_volume_sol as total_volume_sol_state,
    b.total_volume_usd as total_volume_usd_state,
    b.last_trade_time as last_trade_timestamp,
    
    -- Add direction splits from recent analysis
    COALESCE(d.buys, b.trade_count) as buys_state, 
    COALESCE(d.sells, 0) as sells_state,
    COALESCE(d.buy_volume_sol, b.total_volume_sol) as buy_volume_sol_state,
    COALESCE(d.sell_volume_sol, 0) as sell_volume_sol_state,
    COALESCE(d.buy_volume_usd, b.total_volume_usd) as buy_volume_usd_state,
    COALESCE(d.sell_volume_usd, 0) as sell_volume_usd_state,
    
    -- Additional metrics
    COALESCE(d.avg_trade_size_sol, b.total_volume_sol / NULLIF(b.trade_count, 0)) as avg_trade_size_sol_state,
    COALESCE(d.max_trade_size_sol, b.total_volume_sol / NULLIF(b.trade_count, 0)) as max_trade_size_sol_state,
    COALESCE(d.min_trade_size_sol, b.total_volume_sol / NULLIF(b.trade_count, 0)) as min_trade_size_sol_state,
    COALESCE(d.first_trade_timestamp, b.last_trade_time) as first_trade_timestamp
    
FROM trader_base b
LEFT JOIN trader_direction_split d ON b.trader = d.trader
WHERE b.trade_count > 0
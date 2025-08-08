{{ config(
    materialized='materialized_view',
    engine='AggregatingMergeTree()',
    order_by=['trader', 'other_mint'],
    catchup=false,
    description='Real-time trader aggregates using dbt-clickhouse materialized view'
) }}


SELECT 
    trader,
    assumeNotNull(other_mint) AS other_mint, 
    countState() AS trade_count_state,
    sumState(volume_usd) AS volume_usd_state,
    
    sumStateIf(token_amount, trade_direction = 'buy') AS tokens_bought_state,
    sumStateIf(anchor_amount, trade_direction = 'buy') AS anchor_spent_state,
    sumStateIf(token_amount, trade_direction = 'sell') AS tokens_sold_state,
    sumStateIf(anchor_amount, trade_direction = 'sell') AS anchor_received_state,
    
    minState(block_timestamp) AS first_trade_time_state,
    maxState(block_timestamp) AS last_trade_time_state,
    
    avgStateIf(price_in_anchor, trade_direction = 'buy') AS avg_buy_price_state,
    avgStateIf(price_in_anchor, trade_direction = 'sell') AS avg_sell_price_state

FROM {{ ref('stg_solana_analytics__trades') }}
WHERE other_mint IS NOT NULL
  AND other_mint != ''
GROUP BY trader, other_mint
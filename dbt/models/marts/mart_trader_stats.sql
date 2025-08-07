{{ config(
    materialized='view'
) }}


SELECT 
    trader,
    toUInt64(buys_state) AS buys,
    toUInt64(sells_state) AS sells,
    toString(total_volume_sol_state) AS volumeSol,
    toString(total_volume_usd_state) AS volumeUsd,
    last_trade_timestamp
FROM {{ ref('int_trader_aggregates') }}
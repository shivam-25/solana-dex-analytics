{{ config(
    materialized='view'
) }}

SELECT 
    trader,
    mint,
    toString(sum(realized_pnl_sol)) AS realizedPnlSol,
    toString(sum(realized_pnl_usd)) AS realizedPnlUsd,
    max(block_timestamp) AS last_trade_timestamp
FROM {{ ref('int_position_tracking') }}
FINAL
GROUP BY trader, mint
HAVING sum(realized_pnl_sol) != 0 OR sum(realized_pnl_usd) != 0
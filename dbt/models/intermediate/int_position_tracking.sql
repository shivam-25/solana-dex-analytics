{{ config(
    materialized='incremental',
    engine='SummingMergeTree()',
    order_by=['trader', 'mint', 'block_timestamp'],
    partition_by='toYYYYMM(block_timestamp)'
) }}

WITH trade_positions AS (
    SELECT 
        trader,
        coalesce(other_mint, '') AS mint,
        trade_direction,
        token_amount,
        volume_sol,
        volume_usd,
        price_sol,
        price_usd,
        block_timestamp,
        
        -- Running position calculation
        sumIf(token_amount, trade_direction = 'buy') OVER (
            PARTITION BY trader, other_mint 
            ORDER BY block_timestamp
        ) AS cumulative_bought,
        
        sumIf(token_amount, trade_direction = 'sell') OVER (
            PARTITION BY trader, other_mint 
            ORDER BY block_timestamp
        ) AS cumulative_sold,
        
        -- Cost basis tracking
        sumIf(volume_sol, trade_direction = 'buy') OVER (
            PARTITION BY trader, other_mint 
            ORDER BY block_timestamp
        ) AS cumulative_cost_sol,
        
        sumIf(volume_usd, trade_direction = 'buy') OVER (
            PARTITION BY trader, other_mint 
            ORDER BY block_timestamp
        ) AS cumulative_cost_usd
        
    FROM {{ ref('stg_trades') }}
    WHERE other_mint IS NOT NULL
    
    {% if is_incremental() %}
      AND block_timestamp > (
        SELECT max(block_timestamp) 
        FROM {{ this }}
        WHERE trader = stg_trades.trader 
          AND mint = stg_trades.other_mint
      )
    {% endif %}
)

SELECT 
    trader,
    mint,
    block_timestamp,
    
    -- Position tracking
    cumulative_bought - cumulative_sold AS net_position,
    cumulative_bought AS total_bought,
    cumulative_sold AS total_sold,
    
    -- Average cost basis
    CASE 
        WHEN cumulative_bought > 0 THEN cumulative_cost_sol / cumulative_bought
        ELSE 0
    END AS avg_cost_basis_sol,
    
    CASE 
        WHEN cumulative_bought > 0 THEN cumulative_cost_usd / cumulative_bought
        ELSE 0
    END AS avg_cost_basis_usd,
    
    -- Realized PnL calculation (FIFO approximation using average cost)
    CASE 
        WHEN trade_direction = 'sell' THEN
            token_amount * (price_sol - (cumulative_cost_sol / nullIf(cumulative_bought, 0)))
        ELSE 0
    END AS realized_pnl_sol,
    
    CASE 
        WHEN trade_direction = 'sell' THEN
            token_amount * (price_usd - (cumulative_cost_usd / nullIf(cumulative_bought, 0)))
        ELSE 0
    END AS realized_pnl_usd,
    
    trade_direction,
    token_amount,
    volume_sol,
    volume_usd
    
FROM trade_positions
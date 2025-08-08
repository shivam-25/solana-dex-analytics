{{ config(
    materialized='view',
    description='Trader PnL analysis combining aggregated data from intermediate MVs'
) }}

WITH trader_positions AS (
    SELECT 
        trader,
        other_mint,
        
        countMerge(trade_count_state) AS trade_count,
        sumMerge(volume_usd_state) AS total_volume_usd,
        
        sumMerge(tokens_bought_state) AS tokens_bought,
        sumMerge(anchor_spent_state) AS anchor_spent,
        sumMerge(tokens_sold_state) AS tokens_sold,
        sumMerge(anchor_received_state) AS anchor_received,
        
        sumMerge(tokens_bought_state) - sumMerge(tokens_sold_state) AS net_tokens,
        sumMerge(anchor_received_state) - sumMerge(anchor_spent_state) AS net_anchor,
    
        avgMerge(avg_buy_price_state) AS avg_buy_price,
        avgMerge(avg_sell_price_state) AS avg_sell_price,
        
        minMerge(first_trade_time_state) AS first_trade,
        maxMerge(last_trade_time_state) AS last_trade
        
    FROM {{ ref('int_solana_analytics__trader_aggregates') }}
    GROUP BY trader, other_mint
),

current_prices AS (
    SELECT 
        token_mint,
        argMaxMerge(price_anchor_state) AS current_price,
        argMaxMerge(sol_usd_price_state) AS sol_usd_price
    FROM {{ ref('int_solana_analytics__token_prices') }}
    GROUP BY token_mint
)

SELECT 
    tp.trader,
    tp.other_mint AS token_mint,
    tp.trade_count,
    tp.total_volume_usd,
    tp.tokens_bought,
    tp.tokens_sold,
    tp.net_tokens,
    tp.avg_buy_price,
    tp.avg_sell_price,
    cp.current_price,
    
    tp.net_anchor AS realized_pnl_sol,
    tp.net_anchor * cp.sol_usd_price AS realized_pnl_usd,
    
    CASE 
        WHEN tp.net_tokens != 0 THEN 'OPEN'
        ELSE 'CLOSED'
    END AS position_status,
    
    tp.first_trade,
    tp.last_trade,
    
    CASE 
        WHEN tp.avg_buy_price > 0 AND cp.current_price > 0 THEN 
            ((cp.current_price - CAST(tp.avg_buy_price AS Decimal(38,9))) / CAST(tp.avg_buy_price AS Decimal(38,9))) * 100
        ELSE CAST(0 AS Decimal(38,9))
    END AS return_percentage

FROM trader_positions tp
LEFT JOIN current_prices cp ON tp.other_mint = cp.token_mint
WHERE tp.trade_count > 0
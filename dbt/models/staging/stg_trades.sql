{{ config(
    materialized='view',
    engine='MergeTree()',
    order_by=['market', 'trader', 'block_timestamp']
) }}

WITH anchor_tokens AS (
    -- Define anchor tokens inline for compatibility
    SELECT 'So11111111111111111111111111111111111111112' AS mint, 'WSOL' AS symbol
    UNION ALL SELECT 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', 'USDC'
    UNION ALL SELECT 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB', 'USDT'
),

enriched_trades AS (
    SELECT 
        t.*,
        -- Identify anchor tokens
        CASE 
            WHEN t.source_mint IN (SELECT mint FROM anchor_tokens) THEN t.source_mint
            WHEN t.destination_mint IN (SELECT mint FROM anchor_tokens) THEN t.destination_mint
            ELSE NULL 
        END AS anchor_mint,
        
        CASE 
            WHEN t.source_mint IN (SELECT mint FROM anchor_tokens) THEN t.destination_mint
            WHEN t.destination_mint IN (SELECT mint FROM anchor_tokens) THEN t.source_mint
            ELSE NULL 
        END AS other_mint,
        
        -- Determine trade direction (buy = acquiring non-anchor token)
        CASE 
            WHEN t.destination_mint NOT IN (SELECT mint FROM anchor_tokens) 
                AND t.source_mint IN (SELECT mint FROM anchor_tokens) THEN 'buy'
            WHEN t.source_mint NOT IN (SELECT mint FROM anchor_tokens) 
                AND t.destination_mint IN (SELECT mint FROM anchor_tokens) THEN 'sell'
            ELSE NULL
        END AS trade_direction,
        
        -- Calculate SOL amounts
        CASE 
            WHEN t.source_mint = 'So11111111111111111111111111111111111111112' THEN t.amount_in
            WHEN t.destination_mint = 'So11111111111111111111111111111111111111112' THEN t.amount_out
            ELSE toDecimal128(0, 9)
        END AS sol_amount,
        
        -- Calculate other token amount
        CASE 
            WHEN t.source_mint NOT IN (SELECT mint FROM anchor_tokens) THEN t.amount_in
            WHEN t.destination_mint NOT IN (SELECT mint FROM anchor_tokens) THEN t.amount_out
            ELSE toDecimal128(0, 9)
        END AS token_amount,
        
        -- Get price for the non-anchor token
        CASE
            WHEN t.source_mint IN (SELECT mint FROM anchor_tokens) THEN 
                t.amount_in / nullIf(t.amount_out, toDecimal128(0, 9))
            ELSE 
                t.amount_out / nullIf(t.amount_in, toDecimal128(0, 9))
        END AS price_in_anchor,
        
        -- Calculate total liquidity in USD
        (t.total_liquidity_a + t.total_liquidity_b) AS total_liquidity_usd
        
    FROM {{ source('solana_analytics', 'trades_raw') }} t
    WHERE t.amount_in > 0 AND t.amount_out > 0
)

SELECT 
    signature,
    trader,
    slot,
    transaction_index,
    instruction_index,
    market,
    dex,
    source_mint,
    destination_mint,
    anchor_mint,
    other_mint,
    trade_direction,
    amount_in,
    amount_out,
    sol_amount,
    token_amount,
    price_in_anchor,
    
    -- Price calculations
    CASE 
        WHEN anchor_mint = 'So11111111111111111111111111111111111111112' THEN toFloat64(price_in_anchor)
        ELSE toFloat64(0)  -- Would need conversion rates for USDC/USDT to SOL
    END AS price_sol,
    
    CASE 
        WHEN anchor_mint = 'So11111111111111111111111111111111111111112' THEN toFloat64(price_in_anchor) * sol_usd_price
        WHEN anchor_mint IN ('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB') THEN toFloat64(price_in_anchor)
        ELSE toFloat64(0)
    END AS price_usd,
    
    -- Volume calculations
    CASE 
        WHEN anchor_mint = 'So11111111111111111111111111111111111111112' THEN toFloat64(sol_amount)
        ELSE toFloat64(0)  -- Would need conversion for USDC/USDT
    END AS volume_sol,
    
    CASE 
        WHEN anchor_mint = 'So11111111111111111111111111111111111111112' THEN toFloat64(sol_amount) * sol_usd_price
        WHEN anchor_mint IN ('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB') 
            AND trade_direction = 'buy' THEN toFloat64(amount_in)
        WHEN anchor_mint IN ('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB') 
            AND trade_direction = 'sell' THEN toFloat64(amount_out)
        ELSE toFloat64(0)
    END AS volume_usd,
    
    spot_price_a_in_b,
    spot_price_b_in_a,
    sol_usd_price,
    total_liquidity_a,
    total_liquidity_b,
    total_liquidity_usd,
    total_token_supply_a,
    total_token_supply_b,
    block_timestamp
FROM enriched_trades
WHERE anchor_mint IS NOT NULL
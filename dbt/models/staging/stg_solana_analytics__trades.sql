{{ config(
    materialized='view',
    description='Staging layer for raw Solana DEX trades with standardized token identification'
) }}

WITH trades_with_anchors AS (
    SELECT 
        signature,
        trader,
        slot,
        transaction_index,
        instruction_index,
        market,
        replace(replace(dex, '"""', ''), '"', '') AS dex,
        source_mint,
        destination_mint,
        amount_in,
        amount_out,
        spot_price_a_in_b,
        spot_price_b_in_a,
        sol_usd_price,
        total_liquidity_a,
        total_liquidity_b,
        total_token_supply_a,
        total_token_supply_b,
        toDateTime(substring(block_timestamp, 1, 19)) AS block_timestamp,
        
        CASE 
            WHEN {{ is_anchor_token('source_mint') }} THEN source_mint
            WHEN {{ is_anchor_token('destination_mint') }} THEN destination_mint
            ELSE NULL 
        END AS anchor_mint,
        
        CASE 
            WHEN {{ is_anchor_token('source_mint') }} THEN destination_mint
            WHEN {{ is_anchor_token('destination_mint') }} THEN source_mint
            ELSE NULL 
        END AS other_mint,
        
        CASE 
            WHEN {{ not_anchor_token('destination_mint') }} AND {{ is_anchor_token('source_mint') }} THEN 'buy'
            WHEN {{ not_anchor_token('source_mint') }} AND {{ is_anchor_token('destination_mint') }} THEN 'sell'
            ELSE NULL
        END AS trade_direction
        
    FROM {{ ref('seed_sample_trades') }} 
    WHERE amount_in > 0 
      AND amount_out > 0
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
    
    CASE 
        WHEN source_mint = anchor_mint THEN amount_in
        WHEN destination_mint = anchor_mint THEN amount_out
        ELSE 0
    END AS anchor_amount,
    
    CASE 
        WHEN source_mint = other_mint THEN amount_in
        WHEN destination_mint = other_mint THEN amount_out
        ELSE 0
    END AS token_amount,
    
    CASE 
        WHEN trade_direction = 'buy' THEN amount_in / nullIf(amount_out, 0)
        WHEN trade_direction = 'sell' THEN amount_out / nullIf(amount_in, 0)
        ELSE 0
    END AS price_in_anchor,
    
    CASE 
        WHEN anchor_mint = {{ wsol() }} THEN 
            CASE 
                WHEN source_mint = {{ wsol() }} THEN amount_in * sol_usd_price
                ELSE amount_out * sol_usd_price
            END
        WHEN anchor_mint IN {{ anchor_tokens() }} THEN 
            CASE 
                WHEN source_mint = anchor_mint THEN amount_in
                ELSE amount_out
            END
        ELSE CAST(0 AS Decimal(38,18))
    END AS volume_usd,
    
    spot_price_a_in_b,
    spot_price_b_in_a,
    sol_usd_price,
    total_liquidity_a,
    total_liquidity_b,
    total_liquidity_a + total_liquidity_b AS total_liquidity,
    total_token_supply_a,
    total_token_supply_b,
    block_timestamp
    
FROM trades_with_anchors
WHERE anchor_mint IS NOT NULL
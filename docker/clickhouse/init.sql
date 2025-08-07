CREATE DATABASE IF NOT EXISTS solana_analytics;

USE solana_analytics;

-- Create the main trades table
CREATE TABLE IF NOT EXISTS trades_raw (
    -- Transaction information
    signature String,
    trader String,
    slot UInt64,
    transaction_index UInt64,
    instruction_index UInt8,
    
    -- Swap Information
    market String,
    dex String,
    source_mint String,
    destination_mint String,
    source_vault String,
    destination_vault String,
    
    -- Numeric data
    amount_in Decimal(38, 9),
    amount_out Decimal(38, 9),
    spot_price_a_in_b Decimal(38, 9),
    spot_price_b_in_a Decimal(38, 9),
    sol_usd_price Float64,
    
    -- Pool Information
    total_liquidity_a Decimal(38, 9),
    total_liquidity_b Decimal(38, 9),
    total_token_supply_a Decimal(38, 9),
    total_token_supply_b Decimal(38, 9),
    
    -- Timestamp
    block_timestamp DateTime64(9)
    
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(block_timestamp)
ORDER BY (market, trader, block_timestamp);
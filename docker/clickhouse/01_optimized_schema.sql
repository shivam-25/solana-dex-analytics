CREATE DATABASE IF NOT EXISTS solana_analytics;
USE solana_analytics;

-- ============================================
-- 1. MAIN TRADES TABLE
-- ============================================

DROP TABLE IF EXISTS trades_raw;

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
ORDER BY (market, trader, block_timestamp)
SETTINGS index_granularity = 8192;

-- Add indexes for better query performance
ALTER TABLE trades_raw ADD INDEX IF NOT EXISTS idx_trader trader TYPE bloom_filter() GRANULARITY 1;
ALTER TABLE trades_raw ADD INDEX IF NOT EXISTS idx_market market TYPE bloom_filter() GRANULARITY 1;
ALTER TABLE trades_raw ADD INDEX IF NOT EXISTS idx_source_mint source_mint TYPE bloom_filter() GRANULARITY 1;
ALTER TABLE trades_raw ADD INDEX IF NOT EXISTS idx_dest_mint destination_mint TYPE bloom_filter() GRANULARITY 1;
ALTER TABLE trades_raw ADD INDEX IF NOT EXISTS idx_timestamp block_timestamp TYPE minmax GRANULARITY 1;

-- ============================================
-- 2. ANCHOR TOKENS REFERENCE TABLE
-- ============================================

DROP TABLE IF EXISTS anchor_tokens_source;

CREATE TABLE anchor_tokens_source (
    mint String,
    symbol String,
    is_anchor UInt8,
    decimals UInt8
) ENGINE = MergeTree()
ORDER BY mint;

-- Insert anchor token data
INSERT INTO anchor_tokens_source VALUES
    ('So11111111111111111111111111111111111111112', 'WSOL', 1, 9),
    ('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', 'USDC', 1, 6),
    ('Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB', 'USDT', 1, 6);

-- ============================================
-- 3. OPTIONAL DICTIONARY (for performance)
-- ============================================

DROP DICTIONARY IF EXISTS anchor_tokens_dict;

CREATE DICTIONARY IF NOT EXISTS anchor_tokens_dict (
    mint String,
    symbol String,
    is_anchor UInt8,
    decimals UInt8
) PRIMARY KEY mint
SOURCE(CLICKHOUSE(
    HOST 'localhost'
    PORT 9000
    USER 'default'
    PASSWORD ''
    DB 'solana_analytics'
    TABLE 'anchor_tokens_source'
))
LIFETIME(MIN 3600 MAX 7200)
LAYOUT(FLAT());

-- ============================================
-- 4. MODEL RUN STATS TABLE (for dbt tracking)
-- ============================================

CREATE TABLE IF NOT EXISTS model_run_stats (
    model_name String,
    last_run_at DateTime DEFAULT now(),
    rows_affected UInt64 DEFAULT 0
) ENGINE = MergeTree()
ORDER BY (model_name, last_run_at);
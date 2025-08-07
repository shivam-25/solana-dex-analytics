USE solana_analytics;

-- ============================================
-- 1. REAL-TIME LATEST PRICES PER MARKET
-- ============================================

DROP TABLE IF EXISTS mv_market_latest;

CREATE MATERIALIZED VIEW mv_market_latest
ENGINE = ReplacingMergeTree(block_timestamp)
ORDER BY market
POPULATE AS
SELECT 
    market,
    any(source_mint) as source_mint,
    any(destination_mint) as destination_mint,
    any(dex) as dex,
    any(amount_in) as last_amount_in,
    any(amount_out) as last_amount_out,
    any(spot_price_a_in_b) as last_price_a_in_b,
    any(spot_price_b_in_a) as last_price_b_in_a,
    any(sol_usd_price) as last_sol_usd_price,
    any(total_liquidity_a + total_liquidity_b) as total_liquidity,
    max(block_timestamp) as block_timestamp
FROM trades_raw
GROUP BY market;

-- ============================================
-- 2. REAL-TIME TRADER VOLUME AGGREGATES
-- ============================================

DROP TABLE IF EXISTS mv_trader_volume;

CREATE MATERIALIZED VIEW mv_trader_volume
ENGINE = SummingMergeTree()
ORDER BY trader
POPULATE AS
SELECT 
    trader,
    toUInt64(count()) as trade_count,
    sum(CASE 
        WHEN source_mint = 'So11111111111111111111111111111111111111112' THEN toFloat64(amount_in)
        WHEN destination_mint = 'So11111111111111111111111111111111111111112' THEN toFloat64(amount_out)
        ELSE 0
    END) as total_volume_sol,
    sum(CASE 
        WHEN source_mint = 'So11111111111111111111111111111111111111112' THEN toFloat64(amount_in) * sol_usd_price
        WHEN destination_mint = 'So11111111111111111111111111111111111111112' THEN toFloat64(amount_out) * sol_usd_price
        ELSE toFloat64(amount_in)
    END) as total_volume_usd,
    max(block_timestamp) as last_trade_time
FROM trades_raw
GROUP BY trader;

-- ============================================
-- 3. REAL-TIME MARKET HOURLY VOLUME
-- ============================================

DROP TABLE IF EXISTS mv_market_hourly;

CREATE MATERIALIZED VIEW mv_market_hourly
ENGINE = SummingMergeTree()
ORDER BY (market, hour)
POPULATE AS
SELECT 
    market,
    toStartOfHour(block_timestamp) as hour,
    toUInt64(count()) as trades,
    toUInt64(uniq(trader)) as unique_traders,
    sum(toFloat64(amount_in) * sol_usd_price) as volume_usd,
    avg(toFloat64(amount_in) * sol_usd_price) as avg_trade_size
FROM trades_raw
GROUP BY market, hour;

-- ============================================
-- 4. REAL-TIME TOKEN PRICES (Best Market)
-- ============================================

DROP TABLE IF EXISTS mv_token_best_price;

CREATE MATERIALIZED VIEW mv_token_best_price
ENGINE = ReplacingMergeTree(last_updated)
ORDER BY token_mint
POPULATE AS
WITH token_prices AS (
    SELECT 
        CASE 
            WHEN source_mint NOT IN ('So11111111111111111111111111111111111111112', 
                                     'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
                                     'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB')
            THEN source_mint
            ELSE destination_mint
        END as token_mint,
        market,
        CASE 
            WHEN source_mint = 'So11111111111111111111111111111111111111112' 
            THEN toFloat64(amount_in) / nullIf(toFloat64(amount_out), 0)
            WHEN destination_mint = 'So11111111111111111111111111111111111111112'
            THEN toFloat64(amount_out) / nullIf(toFloat64(amount_in), 0)
            ELSE toFloat64(spot_price_a_in_b)
        END as price_in_sol,
        sol_usd_price,
        toFloat64(total_liquidity_a) + toFloat64(total_liquidity_b) as total_liquidity,
        block_timestamp
    FROM trades_raw
)
SELECT 
    token_mint,
    argMax(market, total_liquidity) as best_market,
    argMax(price_in_sol, total_liquidity) as price_sol,
    argMax(price_in_sol * sol_usd_price, total_liquidity) as price_usd,
    max(total_liquidity) as max_liquidity,
    max(block_timestamp) as last_updated
FROM token_prices
WHERE token_mint NOT IN ('So11111111111111111111111111111111111111112', 
                         'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
                         'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB')
  AND token_mint != ''
GROUP BY token_mint;

-- ============================================
-- 5. REAL-TIME TOP TRADERS
-- ============================================

DROP TABLE IF EXISTS mv_top_traders;

CREATE MATERIALIZED VIEW mv_top_traders
ENGINE = ReplacingMergeTree(last_updated)
ORDER BY trader
POPULATE AS
SELECT 
    trader,
    toUInt64(count()) as total_trades,
    sum(CASE 
        WHEN source_mint = 'So11111111111111111111111111111111111111112' 
        THEN toFloat64(amount_in) * sol_usd_price
        WHEN destination_mint = 'So11111111111111111111111111111111111111112' 
        THEN toFloat64(amount_out) * sol_usd_price
        ELSE toFloat64(amount_in)
    END) as volume_usd,
    max(block_timestamp) as last_updated
FROM trades_raw
GROUP BY trader
HAVING volume_usd > 0;

-- ============================================
-- 6. API VIEWS (Query these for instant results)
-- ============================================

-- Instant market prices
CREATE OR REPLACE VIEW api_realtime_market_price AS
SELECT 
    market,
    source_mint,
    destination_mint,
    last_price_a_in_b as price_a_in_b,
    last_price_b_in_a as price_b_in_a,
    last_sol_usd_price as sol_usd_price,
    total_liquidity,
    block_timestamp as last_updated
FROM mv_market_latest
ORDER BY block_timestamp DESC;

-- Instant trader stats
CREATE OR REPLACE VIEW api_realtime_trader_stats AS
SELECT 
    trader,
    trade_count,
    round(total_volume_sol, 4) as volume_sol,
    round(total_volume_usd, 2) as volume_usd,
    round(total_volume_usd / nullIf(trade_count, 0), 2) as avg_trade_usd,
    last_trade_time
FROM mv_trader_volume
WHERE trade_count > 0
ORDER BY total_volume_usd DESC;

-- Instant token prices
CREATE OR REPLACE VIEW api_realtime_token_price AS
SELECT 
    token_mint,
    best_market,
    round(price_sol, 9) as price_sol,
    round(price_usd, 6) as price_usd,
    round(price_sol * max_liquidity, 2) as market_cap_sol,
    round(price_usd * max_liquidity, 2) as market_cap_usd,
    last_updated
FROM mv_token_best_price
WHERE price_sol > 0
ORDER BY market_cap_usd DESC;

-- Instant market volume
CREATE OR REPLACE VIEW api_realtime_market_volume AS
SELECT 
    market,
    hour,
    trades,
    unique_traders,
    round(volume_usd, 2) as volume_usd,
    round(avg_trade_size, 2) as avg_trade_size_usd
FROM mv_market_hourly
WHERE hour >= now() - INTERVAL 24 HOUR
ORDER BY hour DESC, volume_usd DESC;

-- Instant top traders
CREATE OR REPLACE VIEW api_realtime_top_traders AS
SELECT 
    trader,
    total_trades,
    round(volume_usd, 2) as volume_usd,
    round(volume_usd / nullIf(total_trades, 0), 2) as avg_trade_usd,
    last_updated
FROM mv_top_traders
WHERE total_trades > 0
ORDER BY volume_usd DESC
LIMIT 100;

-- ============================================
-- 7. MONITORING VIEWS
-- ============================================

-- Check MV health
CREATE OR REPLACE VIEW mv_health_status AS
SELECT 
    name as materialized_view,
    engine,
    total_rows,
    formatReadableSize(total_bytes) as size,
    metadata_modification_time as last_modified
FROM system.tables
WHERE database = 'solana_analytics' 
  AND name LIKE 'mv_%'
  AND engine NOT LIKE '%View%'
ORDER BY total_bytes DESC;
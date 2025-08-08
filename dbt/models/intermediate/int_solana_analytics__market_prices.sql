{{ config(
    materialized='materialized_view',
    engine='AggregatingMergeTree()',
    order_by=['market'],
    populate=true,
    description='Real-time market price aggregation using State functions'
) }}

SELECT 
    market,
    argMaxState(source_mint, block_timestamp) AS source_mint_state,
    argMaxState(destination_mint, block_timestamp) AS destination_mint_state,
    argMaxState(spot_price_a_in_b, block_timestamp) AS last_price_a_in_b_state,
    argMaxState(spot_price_b_in_a, block_timestamp) AS last_price_b_in_a_state,
    argMaxState(sol_usd_price, block_timestamp) AS last_sol_usd_price_state,
    argMaxState(total_liquidity, block_timestamp) AS total_liquidity_state,
    max(block_timestamp) AS last_updated
FROM {{ ref('stg_solana_analytics__trades') }}
GROUP BY market
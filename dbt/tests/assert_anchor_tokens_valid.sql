SELECT *
FROM {{ ref('stg_trades') }}
WHERE anchor_mint IS NOT NULL
  AND anchor_mint NOT IN (
    'So11111111111111111111111111111111111111112',  -- WSOL
    'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',  -- USDC
    'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB'   -- USDT
)
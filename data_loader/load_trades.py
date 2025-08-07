#!/usr/bin/env python3
"""
Simple trade data loader for ClickHouse
Fixed version without buffer tables
"""

import csv
import os
from datetime import datetime
from clickhouse_driver import Client
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def load_trades_data():
    """Load trades data from CSV into ClickHouse"""
    
    # Connect to ClickHouse
    client = Client(
        host=os.getenv('CLICKHOUSE_HOST', 'localhost'),
        port=int(os.getenv('CLICKHOUSE_PORT', 9000)),
        user=os.getenv('CLICKHOUSE_USER', 'default'),
        password=os.getenv('CLICKHOUSE_PASSWORD', ''),
        database=os.getenv('CLICKHOUSE_DATABASE', 'solana_analytics')
    )
    
    # CSV file path
    csv_path = '../dbt/seeds/sample_trades.csv'
    
    logger.info(f"Loading data from {csv_path}")
    
    # Read and prepare data
    rows_to_insert = []
    errors = 0
    
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        
        for row_num, row in enumerate(reader, 1):
            try:
                # Parse timestamp - handle different formats
                timestamp_str = row['block_timestamp']
                
                # Try different timestamp formats
                dt = None
                for fmt in ['%Y-%m-%d %H:%M:%S.%f', '%Y-%m-%d %H:%M:%S', '%Y-%d-%m %H:%M:%S.%f']:
                    try:
                        dt = datetime.strptime(timestamp_str, fmt)
                        break
                    except:
                        continue
                
                if dt is None:
                    # If all formats fail, try a more flexible approach
                    # Just use the date part and add time
                    try:
                        date_part = timestamp_str.split(' ')[0]
                        dt = datetime.strptime(date_part + ' 00:00:00', '%Y-%m-%d %H:%M:%S')
                    except:
                        logger.warning(f"Row {row_num}: Could not parse timestamp: {timestamp_str}")
                        errors += 1
                        continue
                
                # Clean dex field (remove extra quotes)
                dex = row['dex'].strip('"').strip()
                
                # Prepare row for insertion
                prepared_row = (
                    row['signature'],
                    row['trader'],
                    int(row['slot']),
                    int(row['transaction_index']),
                    int(row['instruction_index']),
                    row['market'],
                    dex,
                    row['source_mint'],
                    row['destination_mint'],
                    row['source_vault'],
                    row['destination_vault'],
                    float(row['amount_in']),
                    float(row['amount_out']),
                    float(row['spot_price_a_in_b']),
                    float(row['spot_price_b_in_a']),
                    float(row['sol_usd_price']),
                    float(row['total_liquidity_a']),
                    float(row['total_liquidity_b']),
                    float(row['total_token_supply_a']),
                    float(row['total_token_supply_b']),
                    dt
                )
                
                rows_to_insert.append(prepared_row)
                
            except Exception as e:
                logger.warning(f"Row {row_num}: Error parsing row: {e}")
                errors += 1
                continue
    
    logger.info(f"Prepared {len(rows_to_insert)} rows for insertion ({errors} errors)")
    
    # Insert data directly into trades_raw table
    if rows_to_insert:
        try:
            client.execute(
                '''
                INSERT INTO trades_raw (
                    signature, trader, slot, transaction_index, instruction_index,
                    market, dex, source_mint, destination_mint, source_vault, destination_vault,
                    amount_in, amount_out, spot_price_a_in_b, spot_price_b_in_a, sol_usd_price,
                    total_liquidity_a, total_liquidity_b, total_token_supply_a, total_token_supply_b,
                    block_timestamp
                ) VALUES
                ''',
                rows_to_insert
            )
            logger.info(f"Successfully inserted {len(rows_to_insert)} trade records")
        except Exception as e:
            logger.error(f"Error inserting data: {e}")
            # Try inserting one by one to find problematic rows
            logger.info("Attempting to insert rows one by one...")
            successful = 0
            for i, row in enumerate(rows_to_insert):
                try:
                    client.execute(
                        '''
                        INSERT INTO trades_raw VALUES
                        ''',
                        [row]
                    )
                    successful += 1
                except Exception as row_error:
                    logger.debug(f"Row {i+1} failed: {row_error}")
            logger.info(f"Successfully inserted {successful} rows individually")
    
    # Verify data was loaded
    try:
        count = client.execute("SELECT COUNT(*) FROM trades_raw")[0][0]
        logger.info(f"Total records in trades_raw: {count}")
    except Exception as e:
        logger.error(f"Could not count records: {e}")
    
    # Optimize table
    try:
        client.execute("OPTIMIZE TABLE trades_raw")
        logger.info("Optimized table trades_raw")
    except Exception as e:
        logger.warning(f"Could not optimize table: {e}")
    
    return True

if __name__ == "__main__":
    success = load_trades_data()
    if success:
        logger.info("Data loading complete!")
    else:
        logger.error("Data loading failed!")
        exit(1)
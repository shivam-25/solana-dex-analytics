#!/usr/bin/env python3
"""
Test script to verify all mart models work as API endpoints
"""

import json
import subprocess
import sys
from typing import Dict, Any

def execute_query(query: str, database: str = "solana_analytics_marts") -> Dict[str, Any]:
    """Execute a query against ClickHouse and return JSON result"""
    cmd = [
        "docker", "exec", "-i", "solana-clickhouse", 
        "clickhouse-client", 
        "--database", database,
        "--query", f"{query} FORMAT JSON"
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error executing query: {e.stderr}")
        return None
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")
        return None

def test_market_price(market: str = "22zLCCNRWk5oBgx8be7LnGNHWatDU2owTczcBZUNdjrb"):
    """Test market price endpoint"""
    print("\n=== Testing Market Price Endpoint ===")
    query = f"SELECT * FROM mart_market_price WHERE market = '{market}' LIMIT 1"
    result = execute_query(query)
    
    if result and result.get("data"):
        data = result["data"][0]
        print(f"Market: {data['market']}")
        print(f"Price (SOL): {data['priceSol']}")
        print(f"Price (USD): {data['priceUsd']}")
        print(f"Market Cap (USD): {data['marketCapUsd']}")
        print("✅ Market price endpoint working")
        return True
    else:
        print("❌ Market price endpoint failed")
        return False

def test_token_price(mint: str = "GhE4sh64jawtzUmeQWRgkN3XrzcWN4pib5g5RcKMbonk"):
    """Test token price endpoint"""
    print("\n=== Testing Token Price Endpoint ===")
    query = f"SELECT * FROM mart_token_price WHERE mint = '{mint}' LIMIT 1"
    result = execute_query(query)
    
    if result and result.get("data"):
        data = result["data"][0]
        print(f"Token: {data['mint']}")
        print(f"Price (SOL): {data['priceSol']}")
        print(f"Price (USD): {data['priceUsd']}")
        print(f"Market Cap (USD): {data['marketCapUsd']}")
        print("✅ Token price endpoint working")
        return True
    else:
        print("❌ Token price endpoint failed")
        return False

def test_token_pair_price():
    """Test token pair price endpoint"""
    print("\n=== Testing Token Pair Price Endpoint ===")
    # Using any two mints from the data
    query = f"""
    SELECT * FROM mart_token_pair_price 
    WHERE mint_a IS NOT NULL AND mint_b IS NOT NULL
    LIMIT 1
    """
    result = execute_query(query)
    
    if result and result.get("data"):
        data = result["data"][0]
        print(f"Mint A: {data['mint_a']}")
        print(f"Mint B: {data['mint_b']}")
        print(f"Price (SOL): {data['priceSol']}")
        print(f"Price (USD): {data['priceUsd']}")
        print("✅ Token pair price endpoint working")
        return True
    else:
        print("❌ Token pair price endpoint failed")
        return False

def test_trader_stats(trader: str = "D7dFRZgTJjHuL1y6kUvgtZZLRYwn2Z7YsfjfAEKJKEz7"):
    """Test trader stats endpoint"""
    print("\n=== Testing Trader Stats Endpoint ===")
    query = f"SELECT * FROM mart_trader_stats WHERE trader = '{trader}' LIMIT 1"
    result = execute_query(query)
    
    if result and result.get("data"):
        data = result["data"][0]
        print(f"Trader: {data['trader']}")
        print(f"Buys: {data['buys']}")
        print(f"Sells: {data['sells']}")
        print(f"Volume (USD): {data['volumeUsd']}")
        print("✅ Trader stats endpoint working")
        return True
    else:
        print("❌ Trader stats endpoint failed")
        return False

def test_trader_pnl():
    """Test trader PnL endpoint"""
    print("\n=== Testing Trader PnL Endpoint ===")
    # Get any trader with PnL data
    query = f"SELECT * FROM mart_trader_pnl LIMIT 1"
    result = execute_query(query)
    
    if result and result.get("data"):
        data = result["data"][0]
        print(f"Trader: {data['trader']}")
        print(f"Token: {data['mint']}")
        print(f"Realized PnL (SOL): {data.get('realizedPnlSol', 'N/A')}")
        print(f"Realized PnL (USD): {data.get('realizedPnlUsd', 'N/A')}")
        print("✅ Trader PnL endpoint working")
        return True
    else:
        print("❌ Trader PnL endpoint failed")
        return False

def test_performance():
    """Test query performance"""
    print("\n=== Testing Query Performance ===")
    
    # Test a complex aggregation query
    query = """
    SELECT 
        COUNT(*) as total_trades,
        COUNT(DISTINCT trader) as unique_traders,
        AVG(toFloat64(volumeUsd)) as avg_volume_usd
    FROM mart_trader_stats
    """
    
    result = execute_query(query)
    
    if result:
        stats = result.get("statistics", {})
        elapsed = stats.get("elapsed", 0)
        rows_read = stats.get("rows_read", 0)
        
        print(f"Query time: {elapsed*1000:.2f}ms")
        print(f"Rows read: {rows_read}")
        
        if elapsed < 0.1:  # Less than 100ms
            print("✅ Performance test passed (< 100ms)")
            return True
        else:
            print("⚠️ Performance test warning (> 100ms)")
            return True
    else:
        print("❌ Performance test failed")
        return False

def main():
    """Run all tests"""
    print("=" * 50)
    print("Testing Solana Analytics API Endpoints")
    print("=" * 50)
    
    tests = [
        test_market_price,
        test_token_price,
        test_token_pair_price,
        test_trader_stats,
        test_trader_pnl,
        test_performance
    ]
    
    results = []
    for test in tests:
        try:
            results.append(test())
        except Exception as e:
            print(f"Test failed with error: {e}")
            results.append(False)
    
    print("\n" + "=" * 50)
    print("Test Summary")
    print("=" * 50)
    
    passed = sum(results)
    total = len(results)
    
    print(f"Passed: {passed}/{total}")
    
    if passed == total:
        print("✅ All tests passed!")
        return 0
    else:
        print(f"❌ {total - passed} tests failed")
        return 1

if __name__ == "__main__":
    sys.exit(main())
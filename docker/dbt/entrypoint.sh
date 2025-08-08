#!/bin/bash
set -e

# Wait for ClickHouse to be ready
echo "Waiting for ClickHouse to be ready..."
while ! clickhouse-client --host clickhouse --query "SELECT 1" > /dev/null 2>&1; do
    sleep 1
done
echo "ClickHouse is ready!"

# Keep container running
exec "$@"
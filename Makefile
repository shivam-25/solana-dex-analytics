# Solana DEX Analytics - Makefile for easy operations

.PHONY: help up down restart clean seed run test validate

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

up: ## Start all services with Docker Compose
	docker-compose up -d
	@echo "Waiting for ClickHouse to be healthy..."
	@while ! docker exec solana-clickhouse clickhouse-client --query "SELECT 1" > /dev/null 2>&1; do \
		sleep 1; \
	done
	@echo "ClickHouse is ready!"

down: ## Stop all services
	docker-compose down

restart: down up ## Restart all services

clean: ## Clean up containers and volumes
	docker-compose down -v
	rm -rf dbt/target dbt/logs dbt/dbt_packages

db-create: ## Create the solana_analytics database
	docker exec solana-clickhouse clickhouse-client --query "CREATE DATABASE IF NOT EXISTS solana_analytics"

seed: ## Load sample data using dbt seed
	docker-compose exec -w /usr/app/dbt dbt dbt seed

run: ## Run dbt models to create all transformations
	docker-compose exec -w /usr/app/dbt dbt dbt run

test: ## Run dbt tests
	docker-compose exec -w /usr/app/dbt dbt dbt test

validate: ## Run API endpoint validation
	@echo "Testing Endpoint 1: Market Price"
	@docker exec solana-clickhouse clickhouse-client --query "SELECT * FROM solana_analytics_marts.mrt_solana_analytics__market_prices LIMIT 1 FORMAT JSONEachRow"
	@echo ""
	@echo "Testing Endpoint 2: Token Price"
	@docker exec solana-clickhouse clickhouse-client --query "SELECT * FROM solana_analytics_marts.mrt_solana_analytics__token_prices LIMIT 1 FORMAT JSONEachRow"

# Full setup workflow
setup: up db-create seed run ## Complete setup: start services, create database, load data, run transformations
	@echo "Setup complete! Run 'make validate' to verify the implementation"

# Development workflow
dev: ## Development workflow: seed + run + test
	@make seed
	@make run
	@make test

# Check data
check-tables: ## List all tables in the database
	docker exec solana-clickhouse clickhouse-client --query "SHOW TABLES FROM solana_analytics"

check-staging: ## Check staging layer data
	docker exec solana-clickhouse clickhouse-client --query "SELECT COUNT(*) as count FROM solana_analytics_staging.stg_solana_analytics__trades"

check-marts: ## Check mart layer data
	docker exec solana-clickhouse clickhouse-client --query "SELECT COUNT(*) as count FROM solana_analytics_marts.mrt_solana_analytics__market_prices"

# API endpoint examples
api-market-price: ## Example: Get market price
	@echo "GET /market/{market}/price"
	docker exec solana-clickhouse clickhouse-client --query \
		"SELECT * FROM solana_analytics_marts.mrt_solana_analytics__market_prices LIMIT 1 FORMAT JSONEachRow"

api-trader-stats: ## Example: Get trader stats  
	@echo "GET /trader/{trader}/stats"
	docker exec solana-clickhouse clickhouse-client --query \
		"SELECT trader, sum(CASE WHEN trade_direction = 'buy' THEN 1 ELSE 0 END) as buys, sum(CASE WHEN trade_direction = 'sell' THEN 1 ELSE 0 END) as sells FROM solana_analytics_staging.stg_solana_analytics__trades GROUP BY trader LIMIT 1 FORMAT JSONEachRow"
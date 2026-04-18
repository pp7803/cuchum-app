.PHONY: help migrate migrate-check db-setup db-reset db-shell db-backup db-list-tables run build test clean

# Database configuration
DB_HOST = 14.225.212.86
DB_PORT = 5432
DB_NAME = cuchum_db
DB_USER = cuchum_admin
DB_PASSWORD = Tsnn@123
PSQL = $(shell which psql || echo "/opt/homebrew/bin/psql")

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

migrate: ## Run all migrations from migrations folder (safe - skips existing)
	@echo "Running all migrations..."
	@for f in migrations/*.sql; do \
		echo "  -> Running $$f"; \
		PGPASSWORD=$(DB_PASSWORD) $(PSQL) -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME) -f "$$f" -q 2>&1 | grep -v "already exists\|NOTICE" || true; \
	done
	@echo "Migration completed!"

migrate-check: ## Check database connection
	@echo "Checking database connection..."
	@PGPASSWORD=$(DB_PASSWORD) $(PSQL) -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME) -c "SELECT version();"
	@echo "Connection successful!"

db-setup: ## Setup database (run all migrations)
	@$(MAKE) migrate

db-reset: ## Reset database (drop all tables and recreate - DANGEROUS!)
	@echo "WARNING: This will drop all tables!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "Dropping all tables..."; \
		PGPASSWORD=$(DB_PASSWORD) $(PSQL) -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME) -c "\
			DROP TABLE IF EXISTS refresh_tokens CASCADE; \
			DROP TABLE IF EXISTS daily_trip_reports CASCADE; \
			DROP TABLE IF EXISTS fuel_reports CASCADE; \
			DROP TABLE IF EXISTS payslips CASCADE; \
			DROP TABLE IF EXISTS contracts CASCADE; \
			DROP TABLE IF EXISTS driver_profiles CASCADE; \
			DROP TABLE IF EXISTS vehicles CASCADE; \
			DROP TABLE IF EXISTS users CASCADE; \
			DROP TYPE IF EXISTS user_role CASCADE; \
			DROP TYPE IF EXISTS user_status CASCADE; \
		"; \
		echo "Re-running migrations..."; \
		$(MAKE) migrate; \
		echo "Database reset completed!"; \
	else \
		echo "Operation cancelled."; \
	fi

db-shell: ## Connect to database shell
	@PGPASSWORD=$(DB_PASSWORD) $(PSQL) -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME)

db-backup: ## Backup database to file
	@echo "Creating database backup..."
	@mkdir -p backups
	@PGPASSWORD=$(DB_PASSWORD) pg_dump -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) $(DB_NAME) > backups/backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "Backup created in backups/ folder"

db-list-tables: ## List all tables in database
	@PGPASSWORD=$(DB_PASSWORD) $(PSQL) -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME) -c "\dt"

# Development commands
run: ## Run the application
	@go run cmd/api/main.go

build: ## Build the application
	@mkdir -p bin
	@go build -o bin/ch-app ./cmd/api
	@echo "Build completed: bin/ch-app"

test: ## Run tests
	@go test -v ./...

clean: ## Clean build artifacts
	@rm -rf bin/
	@echo "Clean completed!"

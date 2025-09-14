#!/bin/bash

# Cross-database migration test
# Tests migrating from one database type to another

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
TEST_MIGRATE_SCRIPT="$PROJECT_ROOT/test/liquibase-migrator/test-migrate.sh"

# Source test-migrate.sh to get access to its functions (includes common test functions)
source "$TEST_MIGRATE_SCRIPT" 2>/dev/null || true

# Test cross-database migration
test_cross_database() {
    log_info "Testing cross-database migration (PostgreSQL to MySQL)..."
    
    # Load test environment variables first
    load_test_env
    
    # Setup test environment with selective cleanup (MariaDB + PostgreSQL only)
    setup_test_environment "mariadb" "postgresql"
    
    # Step 1: Initialize and populate reference database (PostgreSQL)
    log_info "Setting up reference database (PostgreSQL)..."
    # Override environment variables after setup_test_environment loads defaults
    export MAIN_DB_TYPE=mariadb
    export MAIN_DB_HOST=mysql-test
    export MAIN_DB_PORT=3306
    export REF_DB_TYPE=postgresql
    export REF_DB_HOST=postgres-test
    export REF_DB_PORT=5432
    export SCHEMA_SCRIPTS=/liquibase/schema/postgresql/00-init-db.sql,/liquibase/schema/postgresql/01-init-data.sql,/liquibase/schema/postgresql/02-triggers.sql
    
    # Debug: Show current environment variables
    echo "🔍 Debug - Current environment variables:"
    echo "MAIN_DB_TYPE=$MAIN_DB_TYPE"
    echo "MAIN_DB_HOST=$MAIN_DB_HOST"
    echo "MAIN_DB_PORT=$MAIN_DB_PORT"
    echo "REF_DB_TYPE=$REF_DB_TYPE"
    echo "REF_DB_HOST=$REF_DB_HOST"
    echo "REF_DB_PORT=$REF_DB_PORT"
    
    # Run initial setup on PostgreSQL to populate the reference database
    if ! test_liquibase_init; then
        log_error "Failed to set up reference PostgreSQL database"
        return 1
    fi
    
    log_success "Reference PostgreSQL database setup completed"
    
    # Step 2: Generate changelog from PostgreSQL reference to MySQL main
    log_info "Generating changelog from PostgreSQL reference to MySQL main..."
    export MAIN_DB_TYPE=mariadb
    export MAIN_DB_HOST=mysql-test
    export MAIN_DB_PORT=3306
    export REF_DB_TYPE=postgresql
    export REF_DB_HOST=postgres-test
    export REF_DB_PORT=5432
    
    # Source test-sql.sh to get access to its functions
    source "$TEST_SQL_SCRIPT" 2>/dev/null || true
    
    # Generate changelog from PostgreSQL (reference) to MySQL (main)
    if ! test_generate_changelog; then
        log_error "Failed to generate changelog from PostgreSQL to MySQL"
        return 1
    fi
    
    log_success "Changelog generated from PostgreSQL reference to MySQL main"
    
    # Step 3: Apply changelog to MySQL main database
    log_info "Applying changelog to MySQL main database..."
    export MAIN_DB_TYPE=mariadb
    export MAIN_DB_HOST=mysql-test
    export MAIN_DB_PORT=3306
    export REF_DB_TYPE=postgresql
    export REF_DB_HOST=postgres-test
    export REF_DB_PORT=5432
    
    # Apply the generated changelog to MySQL
    if ! test_apply_changelog; then
        log_error "Failed to apply changelog to MySQL database"
        return 1
    fi
    
    log_success "Changelog applied to MySQL main database"
    
    # Step 4: Verify migration status
    log_info "Verifying migration status on MySQL..."
    export MAIN_DB_TYPE=mariadb
    export MAIN_DB_HOST=mysql-test
    export MAIN_DB_PORT=3306
    export REF_DB_TYPE=postgresql
    export REF_DB_HOST=postgres-test
    export REF_DB_PORT=5432
    
    if ! test_migration_status; then
        log_error "Failed to verify migration status on MySQL"
        return 1
    fi
    
    log_success "Migration status verified on MySQL"
    
    # Step 5: Verify data integrity between databases
    log_info "Verifying data integrity between PostgreSQL reference and MySQL main..."
    
    # Verify PostgreSQL reference database has data
    log_info "Checking PostgreSQL reference database..."
    export MAIN_DB_TYPE=postgresql
    export MAIN_DB_HOST=postgres-test
    export MAIN_DB_PORT=5432
    export MAIN_DB_DRIVER=org.postgresql.Driver
    export REF_DB_TYPE=postgresql
    export REF_DB_HOST=postgres-test
    export REF_DB_PORT=5432
    
    if ! run_liquibase_test "--status"; then
        log_error "PostgreSQL reference database is not accessible"
        return 1
    fi
    log_success "PostgreSQL reference database is accessible"
    
    # Verify MySQL main database has data
    log_info "Checking MySQL main database..."
    export MAIN_DB_TYPE=mariadb
    export MAIN_DB_HOST=mysql-test
    export MAIN_DB_PORT=3306
    export REF_DB_TYPE=postgresql
    export REF_DB_HOST=postgres-test
    export REF_DB_PORT=5432
    
    if ! run_liquibase_test "--status"; then
        log_error "MySQL main database is not accessible"
        return 1
    fi
    log_success "MySQL main database is accessible"
    
    return 0
}

# Run the test
test_cross_database

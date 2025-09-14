#!/bin/bash

# PostgreSQL-specific test
# Tests Liquibase migration with PostgreSQL database

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
TEST_MIGRATE_SCRIPT="$PROJECT_ROOT/test/liquibase-migrator/test-migrate.sh"

# Source test-migrate.sh to get access to its functions (includes common test functions)
source "$TEST_MIGRATE_SCRIPT" 2>/dev/null || true

# Test PostgreSQL
test_postgresql() {
    log_info "Testing PostgreSQL..."
    
    # Set environment variables for PostgreSQL test
    export MAIN_DB_TYPE=postgresql
    export MAIN_DB_HOST=postgres-test
    export MAIN_DB_PORT=5432
    export REF_DB_TYPE=postgresql
    export REF_DB_HOST=postgres-test
    export REF_DB_PORT=5432
    export SCHEMA_SCRIPTS=/liquibase/schema/postgresql/00-init-db.sql,/liquibase/schema/postgresql/01-init-data.sql,/liquibase/schema/postgresql/02-triggers.sql
    
    # Call run_all_tests with PostgreSQL types for selective cleanup
    if run_all_tests "postgresql" "postgresql"; then
        log_success "PostgreSQL test completed successfully"
        return 0
    else
        log_error "PostgreSQL test failed"
        return 1
    fi
}

# Run the test
test_postgresql

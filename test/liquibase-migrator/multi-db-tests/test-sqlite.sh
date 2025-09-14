#!/bin/bash

# SQLite-specific test
# Tests Liquibase migration with SQLite database

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
TEST_MIGRATE_SCRIPT="$PROJECT_ROOT/test/liquibase-migrator/test-migrate.sh"

# Source test-migrate.sh to get access to its functions (includes common test functions)
source "$TEST_MIGRATE_SCRIPT" 2>/dev/null || true

# Test SQLite
test_sqlite() {
    log_info "Testing SQLite..."
    
    # Set environment variables for SQLite test
    export MAIN_DB_TYPE=sqlite
    export MAIN_DB_HOST=/data
    export MAIN_DB_PORT=0
    export REF_DB_TYPE=sqlite
    export REF_DB_HOST=/data
    export REF_DB_PORT=0
    export SCHEMA_SCRIPTS=/liquibase/schema/sqlite/00-init-db.sql,/liquibase/schema/sqlite/01-init-data.sql,/liquibase/schema/sqlite/02-triggers.sql
    
    # Call run_all_tests with SQLite types for selective cleanup
    if run_all_tests "sqlite" "sqlite"; then
        log_success "SQLite test completed successfully"
        return 0
    else
        log_error "SQLite test failed"
        return 1
    fi
}

# Run the test
test_sqlite

#!/bin/bash

# MariaDB-specific test
# Tests Liquibase migration with MariaDB database

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
TEST_MIGRATE_SCRIPT="$PROJECT_ROOT/test/liquibase-migrator/test-migrate.sh"

# Source test-migrate.sh to get access to its functions (includes common test functions)
source "$TEST_MIGRATE_SCRIPT" 2>/dev/null || true

# Test MariaDB
test_mariadb() {
    log_info "Testing MariaDB..."
    
    # Set environment variables for MariaDB test (using mysql driver for compatibility)
    export MAIN_DB_TYPE=mariadb
    export MAIN_DB_HOST=mariadb-test
    export MAIN_DB_PORT=3306
    export REF_DB_TYPE=mariadb
    export REF_DB_HOST=mariadb-test
    export REF_DB_PORT=3306
    export SCHEMA_SCRIPTS=/liquibase/schema/mariadb/00-init-db.sql,/liquibase/schema/mariadb/01-init-data.sql,/liquibase/schema/mariadb/02-triggers.sql
    
    # Call run_all_tests with MariaDB types for selective cleanup
    if run_all_tests "mariadb" "mariadb"; then
        log_success "MariaDB test completed successfully"
        return 0
    else
        log_error "MariaDB test failed"
        return 1
    fi
}

# Run the test
test_mariadb

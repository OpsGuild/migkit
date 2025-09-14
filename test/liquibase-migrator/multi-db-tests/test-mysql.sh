#!/bin/bash

# MySQL-specific test
# Tests Liquibase migration with MySQL database

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
TEST_MIGRATE_SCRIPT="$PROJECT_ROOT/test/liquibase-migrator/test-migrate.sh"

# Source test-migrate.sh to get access to its functions (includes common test functions)
source "$TEST_MIGRATE_SCRIPT" 2>/dev/null || true

# Test MySQL
test_mysql() {
    log_info "Testing MySQL..."
    
    # Set environment variables for MySQL test
    export MAIN_DB_TYPE=mysql
    export MAIN_DB_HOST=mysql-test
    export MAIN_DB_PORT=3306
    export REF_DB_TYPE=mysql
    export REF_DB_HOST=mysql-test
    export REF_DB_PORT=3306
    export SCHEMA_SCRIPTS=/liquibase/schema/mysql/00-init-db.sql,/liquibase/schema/mysql/01-init-data.sql,/liquibase/schema/mysql/02-triggers.sql
    
    # Call run_all_tests with MySQL types for selective cleanup
    if run_all_tests "mysql" "mysql"; then
        log_success "MySQL test completed successfully"
        return 0
    else
        log_error "MySQL test failed"
        return 1
    fi
}

# Run the test
test_mysql

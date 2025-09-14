#!/bin/bash

# Test script for multiple database types
# Orchestrates individual database test files
# Tests PostgreSQL, MySQL, MariaDB, and SQLite

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# Source common test functions
if [ -f "$SCRIPT_DIR/../common-test-functions.sh" ]; then
    source "$SCRIPT_DIR/../common-test-functions.sh"
elif [ -f "test/liquibase-migrator/common-test-functions.sh" ]; then
    source "test/liquibase-migrator/common-test-functions.sh"
else
    echo "Error: common-test-functions.sh not found!"
    exit 1
fi

TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Test PostgreSQL
test_postgresql() {
    log_info "Testing PostgreSQL..."
    
    if bash "$SCRIPT_DIR/test-postgresql.sh"; then
        return 0
    else
        return 1
    fi
}

# Test MySQL
test_mysql() {
    log_info "Testing MySQL..."
    
    if bash "$SCRIPT_DIR/test-mysql.sh"; then
        return 0
    else
        return 1
    fi
}

# Test MariaDB
test_mariadb() {
    log_info "Testing MariaDB..."
    
    if bash "$SCRIPT_DIR/test-mariadb.sh"; then
        return 0
    else
        return 1
    fi
}

# Test SQLite
test_sqlite() {
    log_info "Testing SQLite..."
    
    if bash "$SCRIPT_DIR/test-sqlite.sh"; then
        return 0
    else
        return 1
    fi
}

# Test cross-database migration
test_cross_database() {
    log_info "Testing cross-database migration..."
    
    if bash "$SCRIPT_DIR/test-cross-database.sh"; then
        return 0
    else
        return 1
    fi
}

# Test database-specific features
test_database_features() {
    log_info "Testing database-specific features..."
    
    if bash "$SCRIPT_DIR/test-database-features.sh"; then
        return 0
    else
        return 1
    fi
}

# Run all tests
run_all_tests() {
    log_info "Starting Multi-Database Test Suite..."
    echo "================================================"
    
    # Load test environment variables first
    load_test_env
    
    # Setup test environment (load env vars, clean databases, etc.)
    setup_test_environment
    
    run_test "PostgreSQL Database" test_postgresql
    run_test "MySQL Database" test_mysql
    run_test "MariaDB Database" test_mariadb
    run_test "SQLite Database" test_sqlite
    run_test "Cross-Database Migration" test_cross_database
    run_test "Database-Specific Features" test_database_features
    
    echo "================================================"
    log_info "Multi-Database Test Results Summary:"
    log_success "Tests Passed: $TESTS_PASSED"
    if [ $TESTS_FAILED -gt 0 ]; then
        log_error "Tests Failed: $TESTS_FAILED"
    fi
    log_info "Total Tests: $TOTAL_TESTS"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All multi-database tests passed! ✅"
        exit 0
    else
        log_error "Some multi-database tests failed! ❌"
        exit 1
    fi
}

# Helper function to run individual tests
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_info "Running: $test_name"
    
    if $test_function; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$test_name passed"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$test_name failed"
    fi
    
    echo "----------------------------------------"
}

run_all_tests

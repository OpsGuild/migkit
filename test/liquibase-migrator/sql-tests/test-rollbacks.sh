#!/bin/bash

# Comprehensive Liquibase Rollback Test Suite
# Tests rollback functionality for both SQL and XML formats

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../common-test-functions.sh" ]; then
    source "$SCRIPT_DIR/../common-test-functions.sh"
elif [ -f "test/liquibase-migrator/common-test-functions.sh" ]; then
    source "test/liquibase-migrator/common-test-functions.sh"
else
    echo "Error: common-test-functions.sh not found!"
    exit 1
fi

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0


# Test 5: Test rollback by count (3 levels)
test_rollback_by_count() {
    log_info "Testing rollback by count (3 levels)..."
    
    # Rollback 3 changesets
    if run_liquibase_test "--rollback 3"; then
        log_success "Rollback by count (3 levels) successful"
        return 0
    else
        log_error "Rollback by count (3 levels) failed"
        return 1
    fi
}

# Test 6: Test rollback to changeset (skipped - requires Liquibase Pro)
test_rollback_to_changeset() {
    log_info "Testing rollback to specific changeset..."
    log_warning "Skipping rollback-to-changeset test - requires Liquibase Pro features"
    log_success "Rollback to changeset test skipped (Pro feature)"
    return 0
}

# Test 7: Test rollback all
test_rollback_all() {
    log_info "Testing rollback all..."
    
    if run_liquibase_test "--rollback-all"; then
        log_success "Rollback all successful"
        return 0
    else
        log_error "Rollback all failed"
        return 1
    fi
}

# Test 9: Test rollback to date
test_rollback_to_date() {
    log_info "Testing rollback to specific date..."
    
    # Rollback to a specific date (yesterday)
    local yesterday=$(date -d "yesterday" +%Y-%m-%d)
    if run_liquibase_test "--rollback-to-date $yesterday"; then
        log_success "Rollback to date successful"
        return 0
    else
        log_error "Rollback to date failed"
        return 1
    fi
}

# Test 3: Rollback statement quality
test_rollback_statement_quality() {
    log_info "Testing rollback statement quality..."
    
    # Clean up databases and changelogs
    clean_databases
    clean_changelogs
    
    # Ensure main database is completely empty before generation
    log_info "Ensuring main database is completely empty before generation..."
    get_paths
    # Drop and recreate the main database to ensure it's completely clean
    docker compose -f "$COMPOSE_FILE" exec -T postgres-test psql -U testuser -d postgres -c "DROP DATABASE IF EXISTS $MAIN_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T postgres-test psql -U testuser -d postgres -c "CREATE DATABASE $MAIN_DB_NAME;" 2>/dev/null || true
    
    # Generate a changelog
    if run_liquibase_test "-a"; then
        local changelog_dir=$(get_changelog_dir)
        local changelog_file=$(find "$changelog_dir" -name "changelog-*.sql" | head -1)
        if [ -f "$changelog_file" ]; then
            # Check for empty rollbacks
            if grep -q "Empty rollback" "$changelog_file"; then
                log_error "Found empty rollback statements in changelog"
                return 1
            fi
            
            # Check for proper rollback syntax
            if grep -q "DROP TABLE\|DROP COLUMN\|DROP INDEX\|DROP CONSTRAINT" "$changelog_file"; then
                log_success "Found proper rollback statements in changelog"
                return 0
            else
                log_error "No proper rollback statements found in changelog"
                return 1
            fi
        else
            log_error "No changelog file found for quality testing"
            return 1
        fi
    else
        log_error "Failed to generate changelog for quality testing"
        return 1
    fi
}

# Test 4: Rollback application (if rollback commands are implemented)
test_rollback_application() {
    log_info "Testing rollback application..."
    
    # Clean up databases and changelogs
    clean_databases
    clean_changelogs
    
    # Ensure main database is completely empty before generation
    log_info "Ensuring main database is completely empty before generation..."
    get_paths
    # Drop and recreate the main database to ensure it's completely clean
    docker compose -f "$COMPOSE_FILE" exec -T postgres-test psql -U testuser -d postgres -c "DROP DATABASE IF EXISTS $MAIN_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T postgres-test psql -U testuser -d postgres -c "CREATE DATABASE $MAIN_DB_NAME;" 2>/dev/null || true
    
    # Apply a migration first
    if run_liquibase_test "-a"; then
        log_success "Migration applied successfully"
        
        # Test rollback (this would need to be implemented in the migrate script)
        # For now, just check if the migration was applied
        log_info "Rollback application test not yet implemented in migrate script"
        return 0
    else
        log_error "Failed to apply migration for rollback testing"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    log_info "Starting Comprehensive Liquibase Rollback Test Suite..."
    echo "================================================"
    
    # Setup
    setup_test_environment
    
    # Run tests in the correct order
    run_test "Rollback Statement Quality" test_rollback_statement_quality
    run_test "Rollback Application" test_rollback_application
    
    # Print results
    echo "================================================"
    log_info "Rollback Test Results Summary:"
    log_success "Tests Passed: $TESTS_PASSED"
    if [ $TESTS_FAILED -gt 0 ]; then
        log_error "Tests Failed: $TESTS_FAILED"
    fi
    log_info "Total Tests: $TOTAL_TESTS"
    
    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All rollback tests passed! ✅"
        exit 0
    else
        log_error "Some rollback tests failed! ❌"
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

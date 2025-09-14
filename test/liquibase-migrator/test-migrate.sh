#!/bin/bash

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

TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Test 1: Basic Liquibase initialization
test_liquibase_init() {
    log_info "Testing Liquibase initialization..."
    
    if run_liquibase_test "--init"; then
        log_success "Liquibase initialization successful"
        return 0
    else
        log_error "Liquibase initialization failed"
        return 1
    fi
}

# Test 2: Generate chngelog from reference schema
test_generate_changelog() {
    
    if run_liquibase_test "--generate" "REFERENCE_SCHEMA=$SCHEMA_DIR/ref-schema.sql"; then
        log_success "changelog generation successful"

        # Check if a new changelog file was created
        local changelog_dir="/workspace/personal/migkit/sandbox/liquibase-migrator/changelog"
        local new_changelog=$(find "$changelog_dir" -name "changelog-*.sql" -not -name "changelog-initial.sql" | head -1)
        
        if [ -n "$new_changelog" ]; then
            log_success "New changelog file created: $(basename "$new_changelog")"
        else
            log_error "No new changelog file was generated"
            return 1
        fi

        return 0
    else
        log_error "changelog generation failed"
        return 1
    fi
}

# Test 3: Apply generated changelog
test_apply_changelog() {
    log_info "Testing changelog application..."
    
    
    if run_liquibase_test "update"; then
        log_success "Changelog application successful"
        return 0
    else
        log_error "Changelog application failed"
        return 1
    fi
}


# Test 4: Test generate-and-update (-a) option
test_generate_and_update() {
    log_info "Testing generate-and-update (-a) option..."
    
    if run_liquibase_test "-a" "REFERENCE_SCHEMA=$SCHEMA_DIR/ref-schema-modified.sql"; then
        log_success "Generate-and-update operation successful"
        return 0
    else
        log_error "Generate-and-update operation failed"
        return 1
    fi
}

# Test 5: Test migration status
test_migration_status() {
    log_info "Testing migration status..."
    
    if run_liquibase_test "--status"; then
        log_success "Migration status check successful"
        return 0
    else
        log_error "Migration status check failed"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    local main_db_type="${1:-$MAIN_DB_TYPE}"
    local ref_db_type="${2:-$REF_DB_TYPE}"
    
    log_info "Starting Comprehensive Liquibase Migration Test Suite..."
    echo "================================================"
    
    # Load test environment variables first
    load_test_env
    
    # Setup test environment with selective cleanup
    setup_test_environment "$main_db_type" "$ref_db_type"
    
    run_test "Liquibase Initialization" test_liquibase_init
    run_test "Generate Initial Changelog" test_generate_changelog
    run_test "Apply Changelog" test_apply_changelog
    run_test "Generate and Update (-a)" test_generate_and_update
    run_test "Migration Status" test_migration_status
    
    echo "================================================"
    log_info "Migration Test Results Summary:"
    log_success "Tests Passed: $TESTS_PASSED"
    if [ $TESTS_FAILED -gt 0 ]; then
        log_error "Tests Failed: $TESTS_FAILED"
    fi
    log_info "Total Tests: $TOTAL_TESTS"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All migration tests passed! ✅"
        exit 0
    else
        log_error "Some migration tests failed! ❌"
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

# Only run tests if this script is executed directly, not when sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    run_all_tests
fi

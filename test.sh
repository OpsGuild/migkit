#!/bin/bash

# MigKit Test Runner
# This script runs all migration tests from the test/liquibase-migrator directory

# Note: Removed 'set -e' to allow all tests to run even if some fail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test directory
TEST_DIR="test/liquibase-migrator"

# Function to clean changelogs
clean_changelogs() {
    print_info "Cleaning changelogs before running tests..."
    
    local changelog_dir="../../sandbox/liquibase-migrator/changelog"
    
    mkdir -p "$changelog_dir"
    
    find "$changelog_dir" -name "changelog-*.sql" -type f -delete 2>/dev/null || true
    find "$changelog_dir" -name "changelog-initial.sql" -type f -delete 2>/dev/null || true
    
    echo '{"databaseChangeLog": []}' > "$changelog_dir/changelog.json"
    
    local remaining_files=$(find "$changelog_dir" -name "*.sql" -type f | wc -l)
    if [ "$remaining_files" -eq 0 ]; then
        print_success "Changelogs cleaned - no generated files remain"
        if grep -q '"databaseChangeLog": \[\]' "$changelog_dir/changelog.json"; then
            print_success "changelog.json properly reset to empty state"
        else
            print_error "changelog.json was not properly reset!"
            cat "$changelog_dir/changelog.json"
        fi
    else
        print_error "Warning: $remaining_files SQL files still exist after cleanup"
        find "$changelog_dir" -name "*.sql" -type f
    fi
}

# Function to print colored output
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Check if test directory exists
if [ ! -d "$TEST_DIR" ]; then
    print_error "Test directory $TEST_DIR not found!"
    exit 1
fi

cd "$TEST_DIR"

print_header "MigKit Test Suite"

clean_changelogs

# Verify cleanup was successful before proceeding
verify_cleanup() {
    print_info "Verifying cleanup was successful..."
    
    local changelog_dir="../../sandbox/liquibase-migrator/changelog"
    local issues=0
    
    # Check if any generated SQL files still exist
    local remaining_sql_files=$(find "$changelog_dir" -name "*.sql" -type f 2>/dev/null | wc -l)
    if [ "$remaining_sql_files" -gt 0 ]; then
        print_error "Found $remaining_sql_files SQL files that should have been cleaned:"
        find "$changelog_dir" -name "*.sql" -type f 2>/dev/null
        issues=$((issues + 1))
    fi
    
    # Check if changelog.json is properly reset
    if [ -f "$changelog_dir/changelog.json" ]; then
        if ! grep -q '"databaseChangeLog": \[\]' "$changelog_dir/changelog.json" 2>/dev/null; then
            print_error "changelog.json was not properly reset to empty state:"
            cat "$changelog_dir/changelog.json"
            issues=$((issues + 1))
        fi
    else
        print_error "changelog.json file is missing!"
        issues=$((issues + 1))
    fi
    
    if [ "$issues" -eq 0 ]; then
        print_success "Cleanup verification passed - no issues found"
        return 0
    else
        print_error "Cleanup verification failed - $issues issue(s) found"
        return 1
    fi
}

# Verify cleanup before proceeding
if ! verify_cleanup; then
    print_error "Cleanup verification failed! Aborting tests."
    exit 1
fi

print_info "Running all migration tests..."

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test script
run_test() {
    local test_name="$1"
    local test_script="$2"
    
    if [ ! -f "$test_script" ]; then
        print_error "Test script $test_script not found!"
        return 1
    fi
    
    print_header "Running $test_name"
    
    if bash "$test_script"; then
        print_success "$test_name completed successfully"
        ((PASSED_TESTS++))
    else
        print_error "$test_name failed"
        ((FAILED_TESTS++))
    fi
    
    ((TOTAL_TESTS++))
    echo ""
}

# Run all test scripts
run_test "SQL Migration Tests" "sql-tests/test-sql.sh"
run_test "SQL Rollback Tests" "sql-tests/test-rollbacks.sh"
run_test "XML Migration Tests" "xml-tests/test-xml.sh"
run_test "Scenario Tests with Differences" "scenario-tests/test-with-differences.sh"
run_test "Multi-Database Tests" "multi-db-tests/test-multi-db.sh"
run_test "Version Tests" "scenario-tests/version.sh"

# Print summary
print_header "Test Summary"
echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    print_success "All tests passed! 🎉"
    exit 0
else
    print_error "Some tests failed! ❌"
    exit 1
fi


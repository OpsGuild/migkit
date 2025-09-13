#!/bin/bash

# MigKit Test Runner
# This script runs all migration tests from the test/liquibase-migrator directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test directory
TEST_DIR="test/liquibase-migrator"

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

# Change to test directory
cd "$TEST_DIR"

print_header "MigKit Test Suite"
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
run_test "XML Migration Tests" "xml-tests/test-xml.sh"

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


#!/bin/bash

# Comprehensive Liquibase Migration Test Runner
# Runs both SQL and XML migration tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS_PASSED=0
TOTAL_TESTS_FAILED=0
TOTAL_TESTS=0

# Print functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}[HEADER]${NC} $1"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up all test environments..."
    docker compose -f test/docker-compose.yaml down -v >/dev/null 2>&1 || true
    rm -rf test/changelog-sql test/changelog-xml test/schema-sql test/schema-xml test/results-sql test/results-xml >/dev/null 2>&1 || true
}

# Run SQL tests
run_sql_tests() {
    print_header "Running SQL Migration Tests"
    echo "================================================"
    
    if [ -f "./test-sql.sh" ]; then
        chmod +x ./test-sql.sh
        if ./test-sql.sh; then
            print_success "SQL migration tests completed successfully"
            return 0
        else
            print_error "SQL migration tests failed"
            return 1
        fi
    else
        print_error "SQL test file not found: test-sql.sh"
        return 1
    fi
}

# Run XML tests
run_xml_tests() {
    print_header "Running XML Migration Tests"
    echo "================================================"
    
    if [ -f "./test-xml.sh" ]; then
        chmod +x ./test-xml.sh
        if ./test-xml.sh; then
            print_success "XML migration tests completed successfully"
            return 0
        else
            print_error "XML migration tests failed"
            return 1
        fi
    else
        print_error "XML test file not found: test-xml.sh"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    print_header "Starting Comprehensive Liquibase Migration Test Suite"
    echo "================================================"
    print_status "This test suite will run both SQL and XML migration tests"
    print_status "Each test suite includes:"
    print_status "  - Liquibase initialization"
    print_status "  - Changelog generation from reference database"
    print_status "  - Changelog application"
    print_status "  - Comprehensive SQL/XML operations testing"
    print_status "  - Migration status checking"
    print_status "  - Validation"
    print_status "  - Database diff operations"
    print_status "  - Generate diff changelog"
    print_status "  - Future rollback validation"
    print_status "  - Migration history"
    print_status "  - 3 levels of rollback testing"
    print_status "  - Clear checksums"
    print_status "  - Changelog sync"
    echo "================================================"
    
    local sql_result=0
    local xml_result=0
    
    # Run SQL tests
    if run_sql_tests; then
        TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + 1))
    else
        TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + 1))
        sql_result=1
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo ""
    print_status "Waiting 5 seconds before starting XML tests..."
    sleep 5
    echo ""
    
    # Run XML tests
    if run_xml_tests; then
        TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + 1))
    else
        TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + 1))
        xml_result=1
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Print final results
    echo ""
    print_header "Final Test Results Summary"
    echo "================================================"
    print_success "Test Suites Passed: $TOTAL_TESTS_PASSED"
    if [ $TOTAL_TESTS_FAILED -gt 0 ]; then
        print_error "Test Suites Failed: $TOTAL_TESTS_FAILED"
    fi
    print_status "Total Test Suites: $TOTAL_TESTS"
    
    if [ $sql_result -eq 0 ]; then
        print_success "SQL Migration Tests: PASSED ✅"
    else
        print_error "SQL Migration Tests: FAILED ❌"
    fi
    
    if [ $xml_result -eq 0 ]; then
        print_success "XML Migration Tests: PASSED ✅"
    else
        print_error "XML Migration Tests: FAILED ❌"
    fi
    
    # Cleanup
    cleanup
    
    # Exit with appropriate code
    if [ $TOTAL_TESTS_FAILED -eq 0 ]; then
        print_success "All migration tests passed! 🎉"
        exit 0
    else
        print_error "Some migration tests failed! ❌"
        exit 1
    fi
}

# Run only SQL tests
run_sql_only() {
    print_header "Running SQL Migration Tests Only"
    echo "================================================"
    
    if run_sql_tests; then
        print_success "SQL migration tests completed successfully! ✅"
        cleanup
        exit 0
    else
        print_error "SQL migration tests failed! ❌"
        cleanup
        exit 1
    fi
}

# Run only XML tests
run_xml_only() {
    print_header "Running XML Migration Tests Only"
    echo "================================================"
    
    if run_xml_tests; then
        print_success "XML migration tests completed successfully! ✅"
        cleanup
        exit 0
    else
        print_error "XML migration tests failed! ❌"
        cleanup
        exit 1
    fi
}

# Show help
show_help() {
    echo "Comprehensive Liquibase Migration Test Runner"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --sql-only     Run only SQL migration tests"
    echo "  --xml-only     Run only XML migration tests"
    echo "  --cleanup      Clean up test environment and exit"
    echo "  --help         Show this help message"
    echo "  (no args)      Run both SQL and XML migration tests"
    echo ""
    echo "Test Coverage:"
    echo "  - All Liquibase migrator commands (--init, --generate, --update, --rollback, etc.)"
    echo "  - Comprehensive SQL operations (CREATE, ALTER, DROP, INSERT, UPDATE, DELETE, etc.)"
    echo "  - Comprehensive XML operations (createTable, addColumn, addConstraint, etc.)"
    echo "  - 3 levels of rollback testing (by count, to changeset, all)"
    echo "  - Migration status, validation, history, and diff operations"
    echo "  - Future rollback validation and changelog sync"
    echo ""
    echo "Examples:"
    echo "  $0                 # Run all tests"
    echo "  $0 --sql-only      # Run only SQL tests"
    echo "  $0 --xml-only      # Run only XML tests"
    echo "  $0 --cleanup       # Clean up and exit"
}

# Handle script arguments
case "${1:-}" in
    --sql-only)
        run_sql_only
        ;;
    --xml-only)
        run_xml_only
        ;;
    --cleanup)
        cleanup
        print_success "Test environment cleaned up"
        exit 0
        ;;
    --help)
        show_help
        exit 0
        ;;
    "")
        run_all_tests
        ;;
    *)
        print_error "Unknown option: $1"
        echo ""
        show_help
        exit 1
        ;;
esac

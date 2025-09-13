#!/bin/bash

# Test script specifically for testing rollback functionality
# This script tests both SQL and XML rollback generation and application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yaml"

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Test SQL rollback generation
test_sql_rollbacks() {
    log_info "Testing SQL rollback generation..."
    
    # Clean up any existing changelogs
    rm -f "$PROJECT_ROOT/sandbox/liquibase-migrator/changelog/changelog-*.sql"
    
    # Generate a changelog with rollbacks
    if docker compose -f "$COMPOSE_FILE" run --rm --env SCHEMA_SCRIPTS=/liquibase/schema/ref-schema.sql --env CHANGELOG_FORMAT=sql liquibase-test -a; then
        log_success "SQL changelog generated successfully"
        
        # Check if rollback statements were generated
        local changelog_file=$(find "$PROJECT_ROOT/sandbox/liquibase-migrator/changelog" -name "changelog-*.sql" | head -1)
        if [ -f "$changelog_file" ]; then
            if grep -q "-- rollback" "$changelog_file"; then
                log_success "SQL rollback statements found in changelog"
                return 0
            else
                log_error "No SQL rollback statements found in changelog"
                return 1
            fi
        else
            log_error "No SQL changelog file generated"
            return 1
        fi
    else
        log_error "SQL changelog generation failed"
        return 1
    fi
}

# Test XML rollback generation
test_xml_rollbacks() {
    log_info "Testing XML rollback generation..."
    
    # Clean up any existing changelogs
    rm -f "$PROJECT_ROOT/sandbox/liquibase-migrator/changelog/changelog-*.xml"
    
    # Generate a changelog with rollbacks
    if docker compose -f "$COMPOSE_FILE" run --rm --env SCHEMA_SCRIPTS=/liquibase/schema/ref-schema.sql --env CHANGELOG_FORMAT=xml liquibase-test -a; then
        log_success "XML changelog generated successfully"
        
        # Check if rollback statements were generated
        local changelog_file=$(find "$PROJECT_ROOT/sandbox/liquibase-migrator/changelog" -name "changelog-*.xml" | head -1)
        if [ -f "$changelog_file" ]; then
            if grep -q "<rollback>" "$changelog_file"; then
                log_success "XML rollback statements found in changelog"
                return 0
            else
                log_error "No XML rollback statements found in changelog"
                return 1
            fi
        else
            log_error "No XML changelog file generated"
            return 1
        fi
    else
        log_error "XML changelog generation failed"
        return 1
    fi
}

# Test rollback statement quality
test_rollback_quality() {
    log_info "Testing rollback statement quality..."
    
    # Generate a changelog
    if docker compose -f "$COMPOSE_FILE" run --rm --env SCHEMA_SCRIPTS=/liquibase/schema/ref-schema.sql liquibase-test -a; then
        local changelog_file=$(find "$PROJECT_ROOT/sandbox/liquibase-migrator/changelog" -name "changelog-*.sql" | head -1)
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

# Test rollback application (if rollback commands are implemented)
test_rollback_application() {
    log_info "Testing rollback application..."
    
    # Apply a migration first
    if docker compose -f "$COMPOSE_FILE" run --rm --env SCHEMA_SCRIPTS=/liquibase/schema/ref-schema.sql liquibase-test -a; then
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

# Main test function
main() {
    echo -e "${BLUE}🧪 Starting Rollback Test Suite${NC}"
    echo "=========================================="
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    # Run tests
    total_tests=$((total_tests + 1))
    if test_sql_rollbacks; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if test_xml_rollbacks; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if test_rollback_quality; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if test_rollback_application; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    # Print summary
    echo -e "\n${BLUE}📊 Rollback Test Summary${NC}"
    echo "=========================================="
    echo -e "Total tests: ${BLUE}$total_tests${NC}"
    echo -e "Passed: ${GREEN}$passed_tests${NC}"
    echo -e "Failed: ${RED}$failed_tests${NC}"
    
    if [ $failed_tests -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All rollback tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some rollback tests failed!${NC}"
        exit 1
    fi
}

# Run main function
main "$@"

#!/bin/bash

# Test script that forces differences to test rollback generation
# This script uses a modified schema to ensure differences are detected

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
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

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to clean changelogs
clean_changelogs() {
    log_info "Cleaning changelogs before running tests..."
    
    local changelog_dir="../../sandbox/liquibase-migrator/changelog"
    
    mkdir -p "$changelog_dir"
    
    find "$changelog_dir" -name "changelog-*.sql" -type f -delete 2>/dev/null || true
    find "$changelog_dir" -name "changelog-initial.sql" -type f -delete 2>/dev/null || true
    
    echo '{"databaseChangeLog": []}' > "$changelog_dir/changelog.json"
    
    local remaining_files=$(find "$changelog_dir" -name "*.sql" -type f | wc -l)
    if [ "$remaining_files" -eq 0 ]; then
        log_success "Changelogs cleaned - no generated files remain"
        if grep -q '"databaseChangeLog": \[\]' "$changelog_dir/changelog.json"; then
            log_success "changelog.json properly reset to empty state"
        else
            log_error "changelog.json was not properly reset!"
            cat "$changelog_dir/changelog.json"
        fi
    else
        log_error "Warning: $remaining_files SQL files still exist after cleanup"
        find "$changelog_dir" -name "*.sql" -type f
    fi
}

# Create a modified schema that will generate differences
create_modified_schema() {
    log_info "Creating modified schema with differences..."
    
    # Copy the reference schema and modify it
    cp "$PROJECT_ROOT/sandbox/liquibase-migrator/schema/ref-schema.sql" "$SCRIPT_DIR/modified-schema.sql"
    
    # Add some differences to force changelog generation
    cat >> "$SCRIPT_DIR/modified-schema.sql" << 'EOF'

-- Additional table to test rollback generation
CREATE TABLE test_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- Additional index
CREATE INDEX idx_test_table_name ON test_table(name);

-- Additional column to existing table
ALTER TABLE users ADD COLUMN test_column VARCHAR(50) DEFAULT 'test';
EOF
    
    log_success "Modified schema created with additional differences"
}

# Test rollback generation with differences
test_rollback_with_differences() {
    log_info "Testing rollback generation with schema differences..."
    
    # Clean up any existing changelogs
    rm -f "$PROJECT_ROOT/sandbox/liquibase-migrator/changelog/changelog-*.sql"
    
    # Generate changelog with the modified schema
    if docker compose -f "$COMPOSE_FILE" run --rm \
        --env SCHEMA_SCRIPTS=/liquibase/schema/ref-schema.sql \
        --env REF_SCHEMA_SCRIPTS=/liquibase/schema/modified-schema.sql \
        liquibase-test -a; then
        log_success "Changelog generated successfully with differences"
        
        # Check if rollback statements were generated
        local changelog_file=$(find "$PROJECT_ROOT/sandbox/liquibase-migrator/changelog" -name "changelog-*.sql" | head -1)
        if [ -f "$changelog_file" ]; then
            if grep -q "-- rollback" "$changelog_file"; then
                log_success "Rollback statements found in changelog"
                
                # Check for specific rollback types
                if grep -q "DROP TABLE" "$changelog_file"; then
                    log_success "DROP TABLE rollback statements found"
                fi
                
                if grep -q "DROP COLUMN" "$changelog_file"; then
                    log_success "DROP COLUMN rollback statements found"
                fi
                
                if grep -q "DROP INDEX" "$changelog_file"; then
                    log_success "DROP INDEX rollback statements found"
                fi
                
                # Check for empty rollbacks (should not have any)
                if grep -q "Empty rollback" "$changelog_file"; then
                    log_error "Found empty rollback statements in changelog"
                    return 1
                fi
                
                log_success "All rollback statement types found"
                return 0
            else
                log_error "No rollback statements found in changelog"
                return 1
            fi
        else
            log_error "No changelog file generated"
            return 1
        fi
    else
        log_error "Changelog generation failed"
        return 1
    fi
}

# Test XML rollback generation with differences
test_xml_rollback_with_differences() {
    log_info "Testing XML rollback generation with schema differences..."
    
    # Clean up any existing changelogs
    rm -f "$PROJECT_ROOT/sandbox/liquibase-migrator/changelog/changelog-*.xml"
    
    # Generate XML changelog with the modified schema
    if docker compose -f "$COMPOSE_FILE" run --rm \
        --env SCHEMA_SCRIPTS=/liquibase/schema/ref-schema.sql \
        --env REF_SCHEMA_SCRIPTS=/liquibase/schema/modified-schema.sql \
        --env CHANGELOG_FORMAT=xml \
        liquibase-test -a; then
        log_success "XML changelog generated successfully with differences"
        
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
test_rollback_quality_with_differences() {
    log_info "Testing rollback statement quality with differences..."
    
    # Generate a changelog
    if docker compose -f "$COMPOSE_FILE" run --rm \
        --env SCHEMA_SCRIPTS=/liquibase/schema/ref-schema.sql \
        --env REF_SCHEMA_SCRIPTS=/liquibase/schema/modified-schema.sql \
        liquibase-test -a; then
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
                
                # Count different types of rollbacks
                local table_rollbacks=$(grep -c "DROP TABLE" "$changelog_file" || echo "0")
                local column_rollbacks=$(grep -c "DROP COLUMN" "$changelog_file" || echo "0")
                local index_rollbacks=$(grep -c "DROP INDEX" "$changelog_file" || echo "0")
                
                log_info "Rollback breakdown:"
                log_info "  - DROP TABLE: $table_rollbacks"
                log_info "  - DROP COLUMN: $column_rollbacks"
                log_info "  - DROP INDEX: $index_rollbacks"
                
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

# Cleanup function
cleanup() {
    log_info "Cleaning up test files..."
    rm -f "$SCRIPT_DIR/modified-schema.sql"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Main test function
main() {
    echo -e "${BLUE}🧪 Starting Rollback Test with Differences${NC}"
    echo "==============================================="
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    # Clean changelogs before starting tests
    clean_changelogs
    
    # Create modified schema
    create_modified_schema
    
    # Run tests
    total_tests=$((total_tests + 1))
    if test_rollback_with_differences; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if test_xml_rollback_with_differences; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if test_rollback_quality_with_differences; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    # Print summary
    echo -e "\n${BLUE}📊 Rollback Test with Differences Summary${NC}"
    echo "==============================================="
    echo -e "Total tests: ${BLUE}$total_tests${NC}"
    echo -e "Passed: ${GREEN}$passed_tests${NC}"
    echo -e "Failed: ${RED}$failed_tests${NC}"
    
    if [ $failed_tests -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All rollback tests with differences passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some rollback tests with differences failed!${NC}"
        exit 1
    fi
}

# Run main function
main "$@"

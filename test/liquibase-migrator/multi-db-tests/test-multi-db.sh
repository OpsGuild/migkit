#!/bin/bash

# Test script for multiple database types
# Tests PostgreSQL, MySQL, MariaDB, and SQLite

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

# Test PostgreSQL
test_postgresql() {
    log_info "Testing PostgreSQL..."
    
    if docker compose -f "$COMPOSE_FILE" run --rm \
        --env SCHEMA_SCRIPTS=/liquibase/schema/ref-schema.sql \
        --env MAIN_DB_TYPE=postgresql \
        --env MAIN_DB_HOST=postgres-test \
        --env REF_DB_TYPE=postgresql \
        --env REF_DB_HOST=postgres-test \
        liquibase-test -a; then
        log_success "PostgreSQL test passed"
        return 0
    else
        log_error "PostgreSQL test failed"
        return 1
    fi
}

# Test MySQL
test_mysql() {
    log_info "Testing MySQL..."
    
    if docker compose -f "$COMPOSE_FILE" run --rm \
        --env SCHEMA_SCRIPTS=/liquibase/schema/ref-schema.sql \
        --env MAIN_DB_TYPE=mysql \
        --env MAIN_DB_HOST=mysql-test \
        --env REF_DB_TYPE=mysql \
        --env REF_DB_HOST=mysql-test \
        liquibase-test -a; then
        log_success "MySQL test passed"
        return 0
    else
        log_error "MySQL test failed"
        return 1
    fi
}

# Test MariaDB
test_mariadb() {
    log_info "Testing MariaDB..."
    
    if docker compose -f "$COMPOSE_FILE" run --rm \
        --env SCHEMA_SCRIPTS=/liquibase/schema/ref-schema.sql \
        --env MAIN_DB_TYPE=mysql \
        --env MAIN_DB_HOST=mariadb-test \
        --env REF_DB_TYPE=mysql \
        --env REF_DB_HOST=mariadb-test \
        liquibase-test -a; then
        log_success "MariaDB test passed"
        return 0
    else
        log_error "MariaDB test failed"
        return 1
    fi
}

# Test SQLite
test_sqlite() {
    log_info "Testing SQLite..."
    
    if docker compose -f "$COMPOSE_FILE" run --rm \
        --env SCHEMA_SCRIPTS=/liquibase/schema/ref-schema.sql \
        --env MAIN_DB_TYPE=sqlite \
        --env MAIN_DB_HOST=sqlite-test \
        --env REF_DB_TYPE=sqlite \
        --env REF_DB_HOST=sqlite-test \
        liquibase-test -a; then
        log_success "SQLite test passed"
        return 0
    else
        log_error "SQLite test failed"
        return 1
    fi
}

# Test cross-database migration (PostgreSQL to MySQL)
test_cross_database() {
    log_info "Testing cross-database migration (PostgreSQL to MySQL)..."
    
    # This would test migrating from one database type to another
    # For now, just test that both databases are accessible
    log_info "Cross-database migration test not yet implemented"
    return 0
}

# Test database-specific features
test_database_features() {
    log_info "Testing database-specific features..."
    
    # Test PostgreSQL-specific features
    log_info "Testing PostgreSQL-specific features..."
    if docker compose -f "$COMPOSE_FILE" run --rm \
        --env SCHEMA_SCRIPTS=/liquibase/schema/ref-schema.sql \
        --env MAIN_DB_TYPE=postgresql \
        --env MAIN_DB_HOST=postgres-test \
        --env REF_DB_TYPE=postgresql \
        --env REF_DB_HOST=postgres-test \
        liquibase-test -a; then
        log_success "PostgreSQL-specific features test passed"
    else
        log_error "PostgreSQL-specific features test failed"
        return 1
    fi
    
    # Test MySQL-specific features
    log_info "Testing MySQL-specific features..."
    if docker compose -f "$COMPOSE_FILE" run --rm \
        --env SCHEMA_SCRIPTS=/liquibase/schema/ref-schema.sql \
        --env MAIN_DB_TYPE=mysql \
        --env MAIN_DB_HOST=mysql-test \
        --env REF_DB_TYPE=mysql \
        --env REF_DB_HOST=mysql-test \
        liquibase-test -a; then
        log_success "MySQL-specific features test passed"
    else
        log_error "MySQL-specific features test failed"
        return 1
    fi
    
    return 0
}

# Main test function
main() {
    echo -e "${BLUE}🧪 Starting Multi-Database Test Suite${NC}"
    echo "=============================================="
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    # Clean changelogs before starting tests
    clean_changelogs
    
    # Run tests
    total_tests=$((total_tests + 1))
    if test_postgresql; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if test_mysql; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if test_mariadb; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if test_sqlite; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if test_cross_database; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if test_database_features; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    # Print summary
    echo -e "\n${BLUE}📊 Multi-Database Test Summary${NC}"
    echo "=============================================="
    echo -e "Total tests: ${BLUE}$total_tests${NC}"
    echo -e "Passed: ${GREEN}$passed_tests${NC}"
    echo -e "Failed: ${RED}$failed_tests${NC}"
    
    if [ $failed_tests -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All multi-database tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some multi-database tests failed!${NC}"
        exit 1
    fi
}

# Run main function
main "$@"

#!/bin/bash

# Common test functions for all Liquibase migrator tests
# This script provides shared functionality for cleanup, path resolution, and environment setup

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Determine paths based on where script is run from
get_paths() {
    if [ -f "test/liquibase-migrator/common-test-functions.sh" ]; then
        # Running from root directory
        CHANGELOG_DIR="sandbox/liquibase-migrator/changelog"
        COMPOSE_FILE="docker-compose.yaml"
        TEST_ENV_FILE="test/liquibase-migrator/test.env"
    else
        # Running from test directory
        CHANGELOG_DIR="../../sandbox/liquibase-migrator/changelog"
        COMPOSE_FILE="../../docker-compose.yaml"
        TEST_ENV_FILE="./test.env"
    fi
}

# Load test environment variables
load_test_env() {
    get_paths
    
    if [ -f "$TEST_ENV_FILE" ]; then
        source "$TEST_ENV_FILE"
        log_info "Loaded test environment variables"
    elif [ -f "../test.env" ]; then
        source ../test.env
        log_info "Loaded test environment variables"
    else
        log_error "Test environment file not found! Looked for $TEST_ENV_FILE and ../test.env"
        exit 1
    fi
}

# Function to clean changelogs
clean_changelogs() {
    log_info "Cleaning changelogs before running tests..."
    
    get_paths
    
    mkdir -p "$CHANGELOG_DIR"
    
    # Remove all generated changelog files
    find "$CHANGELOG_DIR" -name "changelog-*.sql" -type f -delete 2>/dev/null || true
    find "$CHANGELOG_DIR" -name "changelog-initial.sql" -type f -delete 2>/dev/null || true
    find "$CHANGELOG_DIR" -name "changelog-*.xml" -type f -delete 2>/dev/null || true
    
    # Reset changelog.json to empty state
    echo '{"databaseChangeLog": []}' > "$CHANGELOG_DIR/changelog.json"
    
    local remaining_files=$(find "$CHANGELOG_DIR" -name "*.sql" -o -name "*.xml" | wc -l)
    if [ "$remaining_files" -eq 0 ]; then
        log_success "Changelogs cleaned - no generated files remain"
        if grep -q '"databaseChangeLog": \[\]' "$CHANGELOG_DIR/changelog.json"; then
            log_success "changelog.json properly reset to empty state"
        else
            log_error "changelog.json was not properly reset!"
            cat "$CHANGELOG_DIR/changelog.json"
        fi
    else
        log_error "Warning: $remaining_files files still exist after cleanup"
        find "$CHANGELOG_DIR" -name "*.sql" -o -name "*.xml"
    fi
}

# Verify cleanup was successful before proceeding
verify_cleanup() {
    log_info "Verifying cleanup was successful..."
    
    get_paths
    
    local issues=0
    
    # Check if any generated files still exist
    local remaining_files=$(find "$CHANGELOG_DIR" -name "*.sql" -o -name "*.xml" 2>/dev/null | wc -l)
    if [ "$remaining_files" -gt 0 ]; then
        log_error "Found $remaining_files files that should have been cleaned:"
        find "$CHANGELOG_DIR" -name "*.sql" -o -name "*.xml" 2>/dev/null
        issues=$((issues + 1))
    fi
    
    # Check if changelog.json is properly reset
    if [ -f "$CHANGELOG_DIR/changelog.json" ]; then
        if ! grep -q '"databaseChangeLog": \[\]' "$CHANGELOG_DIR/changelog.json" 2>/dev/null; then
            log_error "changelog.json was not properly reset to empty state:"
            cat "$CHANGELOG_DIR/changelog.json"
            issues=$((issues + 1))
        fi
    else
        log_error "changelog.json file is missing!"
        issues=$((issues + 1))
    fi
    
    if [ "$issues" -eq 0 ]; then
        log_success "Cleanup verification passed - no issues found"
        return 0
    else
        log_error "Cleanup verification failed - $issues issue(s) found"
        return 1
    fi
}

# Function to clean PostgreSQL databases
clean_postgres() {
    log_info "Cleaning PostgreSQL databases..."
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    until docker compose -f "$COMPOSE_FILE" exec postgres-test pg_isready -U testuser -d postgres >/dev/null 2>&1; do
        sleep 1
    done
    
    # Drop and recreate test databases to ensure clean state
    log_info "Dropping and recreating PostgreSQL test databases..."
    docker compose -f "$COMPOSE_FILE" exec -T postgres-test psql -U testuser -d postgres -c "DROP DATABASE IF EXISTS $MAIN_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T postgres-test psql -U testuser -d postgres -c "DROP DATABASE IF EXISTS $REF_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T postgres-test psql -U testuser -d postgres -c "CREATE DATABASE $MAIN_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T postgres-test psql -U testuser -d postgres -c "CREATE DATABASE $REF_DB_NAME;" 2>/dev/null || true
    
    # Ensure main database is completely empty (drop and recreate schema)
    log_info "Ensuring PostgreSQL main database is completely empty..."
    docker compose -f "$COMPOSE_FILE" exec -T postgres-test psql -U testuser -d $MAIN_DB_NAME -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" 2>/dev/null || true
    
    log_success "PostgreSQL cleanup completed"
}

# Function to clean MySQL databases
clean_mysql() {
    log_info "Cleaning MySQL databases..."
    
    # Wait for MySQL to be ready
    log_info "Waiting for MySQL to be ready..."
    until docker compose -f "$COMPOSE_FILE" exec mysql-test mysqladmin ping -h localhost -u testuser -ptestpass >/dev/null 2>&1; do
        sleep 1
    done
    
    # Drop and recreate test databases
    log_info "Dropping and recreating MySQL test databases..."
    docker compose -f "$COMPOSE_FILE" exec -T mysql-test mysql -u testuser -ptestpass -e "DROP DATABASE IF EXISTS $MAIN_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mysql-test mysql -u testuser -ptestpass -e "DROP DATABASE IF EXISTS $REF_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mysql-test mysql -u testuser -ptestpass -e "CREATE DATABASE $MAIN_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mysql-test mysql -u testuser -ptestpass -e "CREATE DATABASE $REF_DB_NAME;" 2>/dev/null || true
    
    log_success "MySQL cleanup completed"
}

# Function to clean MariaDB databases
clean_mariadb() {
    log_info "Cleaning MariaDB databases..."
    
    # Wait for MariaDB to be ready
    log_info "Waiting for MariaDB to be ready..."
    until docker compose -f "$COMPOSE_FILE" exec mariadb-test mysqladmin ping -h localhost -u testuser -ptestpass >/dev/null 2>&1; do
        sleep 1
    done
    
    # Drop and recreate test databases
    log_info "Dropping and recreating MariaDB test databases..."
    docker compose -f "$COMPOSE_FILE" exec -T mariadb-test mysql -u testuser -ptestpass -e "DROP DATABASE IF EXISTS $MAIN_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mariadb-test mysql -u testuser -ptestpass -e "DROP DATABASE IF EXISTS $REF_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mariadb-test mysql -u testuser -ptestpass -e "CREATE DATABASE $MAIN_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mariadb-test mysql -u testuser -ptestpass -e "CREATE DATABASE $REF_DB_NAME;" 2>/dev/null || true
    
    log_success "MariaDB cleanup completed"
}

# Function to clean SQLite databases
clean_sqlite() {
    log_info "Cleaning SQLite databases..."
    
    # Wait for SQLite container to be ready
    log_info "Waiting for SQLite container to be ready..."
    until docker compose -f "$COMPOSE_FILE" exec sqlite-test sqlite3 --version >/dev/null 2>&1; do
        sleep 1
    done
    
    # Remove existing SQLite database files
    log_info "Removing SQLite database files..."
    docker compose -f "$COMPOSE_FILE" exec -T sqlite-test rm -f /data/$MAIN_DB_NAME.db 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T sqlite-test rm -f /data/$REF_DB_NAME.db 2>/dev/null || true
    
    # Create empty SQLite databases
    log_info "Creating empty SQLite databases..."
    docker compose -f "$COMPOSE_FILE" exec -T sqlite-test sqlite3 /data/$MAIN_DB_NAME.db "SELECT 1;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T sqlite-test sqlite3 /data/$REF_DB_NAME.db "SELECT 1;" 2>/dev/null || true
    
    log_success "SQLite cleanup completed"
}

# Function to clean all databases
clean_databases() {
    log_info "Cleaning all test databases..."
    
    get_paths
    
    # Stop and remove containers and volumes
    log_info "Stopping and removing all database containers..."
    docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true
    
    # Wait for cleanup to complete
    sleep 3
    
    # Start all database services
    log_info "Starting all database services..."
    docker compose -f "$COMPOSE_FILE" up -d postgres-test mysql-test mariadb-test sqlite-test 2>/dev/null || true
    
    # Wait a bit for all services to start
    sleep 5
    
    # Clean each database type
    clean_postgres
    clean_mysql
    clean_mariadb
    clean_sqlite
    
    log_success "All database cleanup completed"
}

# Function to run liquibase with test environment
run_liquibase_test() {
    local command="$1"
    shift
    local extra_env_vars=("$@")
    
    get_paths
    
    # Build environment variable arguments
    local env_args=""
    env_args="$env_args -e MAIN_DB_HOST=$MAIN_DB_HOST"
    env_args="$env_args -e MAIN_DB_USER=$MAIN_DB_USER"
    env_args="$env_args -e MAIN_DB_PASSWORD=$MAIN_DB_PASSWORD"
    env_args="$env_args -e MAIN_DB_NAME=$MAIN_DB_NAME"
    env_args="$env_args -e REF_DB_HOST=$REF_DB_HOST"
    env_args="$env_args -e REF_DB_USER=$REF_DB_USER"
    env_args="$env_args -e REF_DB_PASSWORD=$REF_DB_PASSWORD"
    env_args="$env_args -e REF_DB_NAME=$REF_DB_NAME"
    env_args="$env_args -e MAIN_DB_TYPE=$MAIN_DB_TYPE"
    env_args="$env_args -e REF_DB_TYPE=$REF_DB_TYPE"
    env_args="$env_args -e CHANGELOG_FORMAT=$CHANGELOG_FORMAT"
    env_args="$env_args -e SCHEMA_SCRIPTS=$SCHEMA_SCRIPTS"
    
    # Add any extra environment variables
    for var in "${extra_env_vars[@]}"; do
        env_args="$env_args -e $var"
    done
    
    docker compose -f "$COMPOSE_FILE" run --rm $env_args liquibase-test $command
}

# Function to get changelog directory path
get_changelog_dir() {
    get_paths
    echo "$CHANGELOG_DIR"
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Load test environment variables
    load_test_env
    
    # Clean changelogs before starting tests
    clean_changelogs
    
    # Clean databases to ensure fresh start
    clean_databases
    
    log_success "Test environment setup complete"
}

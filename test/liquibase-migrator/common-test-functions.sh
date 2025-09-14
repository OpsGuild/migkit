#!/bin/bash

# Common test functions for all Liquibase migrator tests
# This script provides shared functionality for cleanup, path resolution, and environment setup

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function to wait for database readiness with timeout
wait_for_db_ready() {
    local service="$1"
    local check_command="$2"
    local timeout="${3:-30}"
    local description="${4:-$service}"
    
    log_info "Waiting for $description to be ready..."
    local count=0
    until eval "$check_command" >/dev/null 2>&1; do
        sleep 1
        count=$((count + 1))
        if [ $count -ge $timeout ]; then
            log_error "$description failed to become ready within ${timeout} seconds"
            return 1
        fi
    done
    log_success "$description is ready"
    return 0
}

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
        # Load environment variables, but don't override existing ones
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            # Only set if not already set
            if [[ -z "${!key}" ]]; then
                export "$key=$value"
            fi
        done < "$TEST_ENV_FILE"
        log_info "Loaded test environment variables"
    elif [ -f "../test.env" ]; then
        # Load environment variables, but don't override existing ones
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            # Only set if not already set
            if [[ -z "${!key}" ]]; then
                export "$key=$value"
            fi
        done < ../test.env
        log_info "Loaded test environment variables"
    else
        log_error "Test environment file not found! Looked for $TEST_ENV_FILE and ../test.env"
        exit 1
    fi
    
    export SCHEMA_DIR="/liquibase/schema/$MAIN_DB_TYPE"
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
    
    # Wait for PostgreSQL to be ready (with timeout)
    log_info "Waiting for PostgreSQL to be ready..."
    local timeout=60
    local count=0
    until docker compose -f "$COMPOSE_FILE" exec postgres-test pg_isready -U testuser -d postgres >/dev/null 2>&1; do
        sleep 1
        count=$((count + 1))
        if [ $count -ge $timeout ]; then
            log_error "PostgreSQL failed to become ready within ${timeout} seconds"
            return 1
        fi
    done
    log_success "PostgreSQL is ready"
    
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
    
    # Wait for MySQL to be ready (with timeout)
    log_info "Waiting for MySQL to be ready..."
    local timeout=60
    local count=0
    until docker compose -f "$COMPOSE_FILE" exec mysql-test mysqladmin ping -h localhost -u testuser -ptestpass >/dev/null 2>&1; do
        sleep 1
        count=$((count + 1))
        if [ $count -ge $timeout ]; then
            log_error "MySQL failed to become ready within ${timeout} seconds"
            return 1
        fi
    done
    log_success "MySQL is ready"
    
    # Drop and recreate test databases
    log_info "Dropping and recreating MySQL test databases..."
    docker compose -f "$COMPOSE_FILE" exec -T mysql-test mysql -u root -prootpass -e "DROP DATABASE IF EXISTS $MAIN_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mysql-test mysql -u root -prootpass -e "DROP DATABASE IF EXISTS $REF_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mysql-test mysql -u root -prootpass -e "CREATE DATABASE $MAIN_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mysql-test mysql -u root -prootpass -e "CREATE DATABASE $REF_DB_NAME;" 2>/dev/null || true
    
    # Grant permissions to testuser
    docker compose -f "$COMPOSE_FILE" exec -T mysql-test mysql -u root -prootpass -e "GRANT ALL PRIVILEGES ON $MAIN_DB_NAME.* TO 'testuser'@'%';" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mysql-test mysql -u root -prootpass -e "GRANT ALL PRIVILEGES ON $REF_DB_NAME.* TO 'testuser'@'%';" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mysql-test mysql -u root -prootpass -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    log_success "MySQL cleanup completed"
}

# Function to clean MariaDB databases
clean_mariadb() {
    log_info "Cleaning MariaDB databases..."
    
    # Wait for MariaDB to be ready (with timeout)
    log_info "Waiting for MariaDB to be ready..."
    local timeout=60
    local count=0
    until docker compose -f "$COMPOSE_FILE" exec mariadb-test mysqladmin ping -h localhost -u testuser -ptestpass >/dev/null 2>&1; do
        sleep 1
        count=$((count + 1))
        if [ $count -ge $timeout ]; then
            log_error "MariaDB failed to become ready within ${timeout} seconds"
            return 1
        fi
    done
    log_success "MariaDB is ready"
    
    # Drop and recreate test databases
    log_info "Dropping and recreating MariaDB test databases..."
    docker compose -f "$COMPOSE_FILE" exec -T mariadb-test mysql -u root -prootpass -e "DROP DATABASE IF EXISTS $MAIN_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mariadb-test mysql -u root -prootpass -e "DROP DATABASE IF EXISTS $REF_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mariadb-test mysql -u root -prootpass -e "CREATE DATABASE $MAIN_DB_NAME;" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mariadb-test mysql -u root -prootpass -e "CREATE DATABASE $REF_DB_NAME;" 2>/dev/null || true
    
    # Grant permissions to testuser
    docker compose -f "$COMPOSE_FILE" exec -T mariadb-test mysql -u root -prootpass -e "GRANT ALL PRIVILEGES ON $MAIN_DB_NAME.* TO 'testuser'@'%';" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mariadb-test mysql -u root -prootpass -e "GRANT ALL PRIVILEGES ON $REF_DB_NAME.* TO 'testuser'@'%';" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T mariadb-test mysql -u root -prootpass -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    log_success "MariaDB cleanup completed"
}

# Function to clean SQLite databases
clean_sqlite() {
    log_info "Cleaning SQLite databases..."
    
    # Wait for SQLite container to be ready (with timeout)
    log_info "Waiting for SQLite container to be ready..."
    local timeout=60
    local count=0
    until docker compose -f "$COMPOSE_FILE" exec sqlite-test sqlite3 --version >/dev/null 2>&1; do
        sleep 1
        count=$((count + 1))
        if [ $count -ge $timeout ]; then
            log_error "SQLite container failed to become ready within ${timeout} seconds"
            return 1
        fi
    done
    log_success "SQLite container is ready"
    
    # Remove existing SQLite database files
    log_info "Removing SQLite database files..."
    docker compose -f "$COMPOSE_FILE" exec -T sqlite-test rm -f /data/$MAIN_DB_NAME.db 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T sqlite-test rm -f /data/$REF_DB_NAME.db 2>/dev/null || true
    
    # Create empty SQLite databases (no dummy table needed - Liquibase will create what it needs)
    log_info "Creating empty SQLite databases..."
    
    # Fix permissions for liquibase-user (UID 1000)
    docker compose -f "$COMPOSE_FILE" exec -T sqlite-test chown 1000:1000 /data/$MAIN_DB_NAME.db /data/$REF_DB_NAME.db 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T sqlite-test chmod 664 /data/$MAIN_DB_NAME.db /data/$REF_DB_NAME.db 2>/dev/null || true
    
    # Fix directory permissions so SQLite can create journal files
    docker compose -f "$COMPOSE_FILE" exec -T sqlite-test chown 1000:1000 /data 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" exec -T sqlite-test chmod 775 /data 2>/dev/null || true
    
    log_success "SQLite cleanup completed"
}

# Function to clean specific databases based on types
clean_databases_selective() {
    local main_db_type="${1:-}"
    local ref_db_type="${2:-}"
    
    log_info "Cleaning databases for types: main=$main_db_type, ref=$ref_db_type"
    
    get_paths
    
    # Determine which services we need
    local services_to_start=()
    local services_to_clean=()
    
    # Add services based on database types
    case "$main_db_type" in
        postgresql) services_to_start+=("postgres-test") && services_to_clean+=("clean_postgres") ;;
        mysql) services_to_start+=("mysql-test") && services_to_clean+=("clean_mysql") ;;
        mariadb) services_to_start+=("mariadb-test") && services_to_clean+=("clean_mariadb") ;;
        sqlite) services_to_start+=("sqlite-test") && services_to_clean+=("clean_sqlite") ;;
        *) log_error "Unsupported main database type: $main_db_type"; return 1 ;;
    esac
    
    case "$ref_db_type" in
        postgresql) services_to_start+=("postgres-test") && services_to_clean+=("clean_postgres") ;;
        mysql) services_to_start+=("mysql-test") && services_to_clean+=("clean_mysql") ;;
        mariadb) services_to_start+=("mariadb-test") && services_to_clean+=("clean_mariadb") ;;
        sqlite) services_to_start+=("sqlite-test") && services_to_clean+=("clean_sqlite") ;;
        *) log_error "Unsupported reference database type: $ref_db_type"; return 1 ;;
    esac
    
    # Remove duplicates from services_to_start
    local unique_services=()
    for service in "${services_to_start[@]}"; do
        if [[ ! " ${unique_services[*]} " =~ " ${service} " ]]; then
            unique_services+=("$service")
        fi
    done
    
    # Remove duplicates from services_to_clean
    local unique_cleaners=()
    for cleaner in "${services_to_clean[@]}"; do
        if [[ ! " ${unique_cleaners[*]} " =~ " ${cleaner} " ]]; then
            unique_cleaners+=("$cleaner")
        fi
    done
    
    if [ ${#unique_services[@]} -eq 0 ]; then
        log_warning "No database services to clean for types: main=$main_db_type, ref=$ref_db_type"
        return 0
    fi
    
    # Stop only the services we need (more efficient)
    log_info "Stopping database containers: ${unique_services[*]}"
    for service in "${unique_services[@]}"; do
        docker compose -f "$COMPOSE_FILE" stop "$service" >/dev/null 2>&1 || true
        docker compose -f "$COMPOSE_FILE" rm -f "$service" >/dev/null 2>&1 || true
    done
    
    # Wait for cleanup to complete
    sleep 2
    
    # Start only the services we need
    log_info "Starting database services: ${unique_services[*]}"
    docker compose -f "$COMPOSE_FILE" up -d "${unique_services[@]}" >/dev/null 2>&1 || true
    
    # Wait for services to start
    sleep 3
    
    # Clean only the databases we need
    local cleanup_failed=0
    for cleaner in "${unique_cleaners[@]}"; do
        if ! $cleaner; then
            log_error "Failed to clean database with $cleaner"
            cleanup_failed=1
        fi
    done
    
    if [ $cleanup_failed -eq 0 ]; then
        log_success "Selective database cleanup completed for: ${unique_services[*]}"
    else
        log_error "Some database cleanup operations failed"
        return 1
    fi
}

# Function to clean all databases (kept for backward compatibility)
clean_databases() {
    log_info "Cleaning all test databases..."
    
    get_paths
    
    # Stop and remove containers and volumes
    log_info "Stopping and removing all database containers..."
    docker compose -f "$COMPOSE_FILE" down -v >/dev/null 2>&1 || true
    
    # Wait for cleanup to complete
    sleep 3
    
    # Start only the required database services
    log_info "Starting required database services..."
    if [ ${#services_to_start[@]} -gt 0 ]; then
        docker compose -f "$COMPOSE_FILE" up -d "${services_to_start[@]}" >/dev/null 2>&1 || true
    fi
    
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
    env_args="$env_args -e MAIN_DB_TYPE=$MAIN_DB_TYPE"
    env_args="$env_args -e MAIN_DB_PORT=$MAIN_DB_PORT"
    env_args="$env_args -e REF_DB_HOST=$REF_DB_HOST"
    env_args="$env_args -e REF_DB_USER=$REF_DB_USER"
    env_args="$env_args -e REF_DB_PASSWORD=$REF_DB_PASSWORD"
    env_args="$env_args -e REF_DB_NAME=$REF_DB_NAME"
    env_args="$env_args -e REF_DB_TYPE=$REF_DB_TYPE"
    env_args="$env_args -e REF_DB_PORT=$REF_DB_PORT"
    env_args="$env_args -e CHANGELOG_FORMAT=$CHANGELOG_FORMAT"
    env_args="$env_args -e SCHEMA_SCRIPTS=$SCHEMA_SCRIPTS"
    env_args="$env_args -e SCHEMA_DIR=/liquibase/schema/$MAIN_DB_TYPE"
    
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
    local main_db_type="${1:-$MAIN_DB_TYPE}"
    local ref_db_type="${2:-$REF_DB_TYPE}"
    
    log_info "Setting up test environment (selective cleanup for $main_db_type -> $ref_db_type)..."
    
    # Note: load_test_env should be called by individual test files before calling this function
    # to avoid environment variable overrides
    
    # Clean changelogs before starting tests
    clean_changelogs
    
    # Clean only the databases we need
    clean_databases_selective "$main_db_type" "$ref_db_type"
    
    log_success "Selective test environment setup complete"
}

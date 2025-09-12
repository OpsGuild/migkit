#!/bin/bash

# Comprehensive Liquibase SQL Migration Test Suite
# Tests all Liquibase migrator commands and SQL operations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_DB="testdb_sql"
REF_DB="testdb_ref_sql"
CHANGELOG_DIR="test/changelog-sql"
SCHEMA_DIR="test/schema-sql"
TEST_RESULTS_DIR="test/results-sql"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
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

# Cleanup function
cleanup() {
    print_status "Cleaning up test environment..."
    docker compose -f test/docker-compose.yaml down -v >/dev/null 2>&1 || true
    rm -rf "$CHANGELOG_DIR" "$SCHEMA_DIR" "$TEST_RESULTS_DIR" >/dev/null 2>&1 || true
}

# Setup test environment
setup_test_environment() {
    print_status "Setting up SQL migration test environment..."
    
    # Create test directories
    mkdir -p "$CHANGELOG_DIR" "$SCHEMA_DIR" "$TEST_RESULTS_DIR"
    
    # Start services
    print_status "Starting test services..."
    docker compose -f test/docker-compose.yaml up -d postgres-test
    
    # Wait for database to be ready
    print_status "Waiting for database to be ready..."
    until docker compose -f test/docker-compose.yaml exec postgres-test pg_isready -U testuser -d postgres >/dev/null 2>&1; do
        sleep 1
    done
    
    # Create test databases (clean up first)
    docker compose -f test/docker-compose.yaml exec -T postgres-test psql -U testuser -d postgres -c "DROP DATABASE IF EXISTS $TEST_DB;" 2>/dev/null || true
    docker compose -f test/docker-compose.yaml exec -T postgres-test psql -U testuser -d postgres -c "DROP DATABASE IF EXISTS $REF_DB;" 2>/dev/null || true
    docker compose -f test/docker-compose.yaml exec -T postgres-test psql -U testuser -d postgres -c "CREATE DATABASE $TEST_DB;"
    docker compose -f test/docker-compose.yaml exec -T postgres-test psql -U testuser -d postgres -c "CREATE DATABASE $REF_DB;"
    
    print_success "Test environment setup complete"
}

# Test 1: Basic Liquibase initialization
test_liquibase_init() {
    print_status "Testing Liquibase initialization..."
    
    # Test --init command (this should just sync the changelog, not apply it)
    if docker compose -f test/docker-compose.yaml run --rm -e LIQ_DB_HOST=postgres-test -e LIQ_DB_USER=testuser -e LIQ_DB_PASSWORD=testpass -e LIQ_DB_NAME="$TEST_DB" liquibase-test --init; then
        print_success "Liquibase initialization successful"
        return 0
    else
        print_error "Liquibase initialization failed"
        return 1
    fi
}

# Test 2: Generate initial changelog from reference database
test_generate_initial_changelog() {
    print_status "Testing initial changelog generation..."
    
    # Create test data that matches the existing init-db.sql schema
    cat > "test/schema/test-data.sql" << 'EOF'
-- Test data for migration testing
-- This data will be inserted into the reference database

-- Insert test users
INSERT INTO users (username, email, first_name, last_name, status) VALUES
('john_doe', 'john@example.com', 'John', 'Doe', 'active'),
('jane_smith', 'jane@example.com', 'Jane', 'Smith', 'active'),
('bob_wilson', 'bob@example.com', 'Bob', 'Wilson', 'active'),
('alice_brown', 'alice@example.com', 'Alice', 'Brown', 'active'),
('charlie_davis', 'charlie@example.com', 'Charlie', 'Davis', 'active');

-- Insert test categories
INSERT INTO categories (name, description, is_active) VALUES
('Technology', 'Posts about technology and programming', true),
('Lifestyle', 'Posts about lifestyle and personal experiences', true),
('Business', 'Posts about business and entrepreneurship', true);

-- Insert test posts
INSERT INTO posts (title, slug, content, excerpt, user_id, category_id, status, published_at) VALUES
('Getting Started with Docker', 'getting-started-with-docker', 'Docker is a powerful containerization platform...', 'Learn the basics of Docker', 1, 1, 'published', CURRENT_TIMESTAMP),
('Healthy Living Tips', 'healthy-living-tips', 'Maintaining a healthy lifestyle is important...', 'Tips for a healthier life', 2, 2, 'published', CURRENT_TIMESTAMP),
('Startup Success Stories', 'startup-success-stories', 'Many successful startups share common traits...', 'What makes startups successful', 3, 3, 'draft', NULL),
('Advanced SQL Techniques', 'advanced-sql-techniques', 'SQL can be much more powerful than basic queries...', 'Master advanced SQL', 1, 1, 'published', CURRENT_TIMESTAMP),
('Work-Life Balance', 'work-life-balance', 'Finding the right balance between work and life...', 'Balancing work and personal life', 4, 2, 'published', CURRENT_TIMESTAMP);

-- Insert test tags
INSERT INTO tags (name, color) VALUES
('docker', '#007bff'),
('programming', '#28a745'),
('health', '#dc3545'),
('business', '#ffc107'),
('sql', '#17a2b8'),
('lifestyle', '#6f42c1');

-- Insert post tags
INSERT INTO post_tags (post_id, tag_id) VALUES
(1, 1), (1, 2), (2, 3), (2, 6), (3, 4), (4, 2), (4, 5), (5, 6);

-- Insert test comments
INSERT INTO comments (post_id, user_id, content, status) VALUES
(1, 2, 'Great introduction to Docker!', 'approved'),
(1, 3, 'Very helpful, thanks for sharing.', 'approved'),
(2, 1, 'These tips are really practical.', 'approved'),
(4, 2, 'Advanced SQL is so powerful!', 'approved'),
(5, 3, 'Work-life balance is crucial.', 'approved');

-- Insert user profiles
INSERT INTO user_profiles (user_id, bio, website, location) VALUES
(1, 'Software developer passionate about DevOps', 'https://johndoe.dev', 'San Francisco, CA'),
(2, 'Health and wellness enthusiast', 'https://janesmith.health', 'New York, NY'),
(3, 'Entrepreneur and business consultant', 'https://bobwilson.biz', 'Austin, TX'),
(4, 'Life coach and productivity expert', 'https://alicebrown.life', 'Seattle, WA'),
(5, 'Tech writer and developer advocate', 'https://charliedavis.tech', 'Boston, MA');
EOF

    # Ensure test database is completely empty (no schema applied)
    print_status "Ensuring test database is empty..."
    docker compose -f test/docker-compose.yaml exec -T postgres-test psql -U testuser -d "$TEST_DB" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
    
    # Note: Schema and data will be applied by the migrate script using REFERENCE_SCHEMA
    
    # Generate changelog using ref-schema.sql for the reference database
    # Note: TEST_DB should be empty, REF_DB will have the reference schema
    if docker compose -f test/docker-compose.yaml run --rm -e LIQ_DB_HOST=postgres-test -e LIQ_DB_USER=testuser -e LIQ_DB_PASSWORD=testpass -e LIQ_DB_NAME="$TEST_DB" -e LIQ_DB_SNAPSHOT="$REF_DB" -e LIQUIBASE_COMMAND_REFERENCE_URL="jdbc:postgresql://postgres-test:5432/$REF_DB" -e REFERENCE_SCHEMA="/liquibase/schema/ref-schema.sql" liquibase-test --generate; then
        print_success "Initial changelog generation successful"
        return 0
    else
        print_error "Initial changelog generation failed"
        return 1
    fi
}

# Test 3: Apply generated changelog
test_apply_changelog() {
    print_status "Testing changelog application..."
    
    if docker compose -f test/docker-compose.yaml run --rm -e LIQ_DB_HOST=postgres-test -e LIQ_DB_USER=testuser -e LIQ_DB_PASSWORD=testpass -e LIQ_DB_NAME="$TEST_DB" liquibase-test --update; then
        print_success "Changelog application successful"
        return 0
    else
        print_error "Changelog application failed"
        return 1
    fi
}

# Test 4: Test all SQL operations with new changeset
test_sql_operations() {
    print_status "Testing comprehensive SQL operations..."
    
    # Create a new changeset with various SQL operations
    cat > "$CHANGELOG_DIR/002-sql-operations.sql" << 'EOF'
--liquibase formatted sql

--changeset migkit:add-user-fields
-- Add new columns to users table
ALTER TABLE users ADD COLUMN phone VARCHAR(20);
ALTER TABLE users ADD COLUMN last_login TIMESTAMP;
ALTER TABLE users ADD COLUMN is_active BOOLEAN DEFAULT true;

--changeset migkit:add-user-sessions-table
-- Create user sessions table
CREATE TABLE user_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);

--changeset migkit:add-post-fields
-- Add new columns to posts table
ALTER TABLE posts ADD COLUMN view_count INTEGER DEFAULT 0;
ALTER TABLE posts ADD COLUMN featured BOOLEAN DEFAULT false;
ALTER TABLE posts ADD COLUMN published_at TIMESTAMP;

CREATE INDEX idx_posts_featured ON posts(featured);
CREATE INDEX idx_posts_view_count ON posts(view_count);
CREATE INDEX idx_posts_published_at ON posts(published_at);

--changeset migkit:add-audit-table
-- Create audit log table
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER NOT NULL,
    action VARCHAR(20) NOT NULL,
    old_values JSONB,
    new_values JSONB,
    changed_by INTEGER REFERENCES users(id),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_log_table_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_changed_at ON audit_log(changed_at);

--changeset migkit:add-data-constraints
-- Add check constraints
ALTER TABLE users ADD CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
ALTER TABLE posts ADD CONSTRAINT chk_status_values CHECK (status IN ('draft', 'published', 'archived'));
ALTER TABLE user_sessions ADD CONSTRAINT chk_expires_future CHECK (expires_at > created_at);

--changeset migkit:insert-test-data
-- Insert test data for new features
INSERT INTO user_sessions (user_id, session_token, expires_at) VALUES
(1, 'session_token_1', CURRENT_TIMESTAMP + INTERVAL '1 day'),
(2, 'session_token_2', CURRENT_TIMESTAMP + INTERVAL '2 days'),
(3, 'session_token_3', CURRENT_TIMESTAMP + INTERVAL '1 hour');

UPDATE posts SET published_at = created_at WHERE status = 'published';
UPDATE posts SET view_count = FLOOR(RANDOM() * 1000) WHERE status = 'published';
UPDATE posts SET featured = true WHERE id IN (1, 4);

--changeset migkit:add-complex-view
-- Create a complex view
CREATE VIEW post_statistics AS
SELECT 
    p.id,
    p.title,
    p.status,
    p.view_count,
    p.featured,
    u.username as author,
    c.name as category,
    COUNT(DISTINCT cm.id) as comment_count,
    COUNT(DISTINCT pt.tag_id) as tag_count,
    p.created_at,
    p.published_at
FROM posts p
LEFT JOIN users u ON p.user_id = u.id
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN comments cm ON p.id = cm.post_id
LEFT JOIN post_tags pt ON p.id = pt.post_id
GROUP BY p.id, p.title, p.status, p.view_count, p.featured, u.username, c.name, p.created_at, p.published_at;

--changeset migkit:add-stored-procedure
-- Create stored procedure
CREATE OR REPLACE FUNCTION update_post_view_count(post_id INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE posts 
    SET view_count = view_count + 1 
    WHERE id = post_id;
    
    INSERT INTO audit_log (table_name, record_id, action, new_values, changed_at)
    VALUES ('posts', post_id, 'UPDATE', jsonb_build_object('view_count', view_count + 1), CURRENT_TIMESTAMP);
END;
$$ LANGUAGE plpgsql;

--changeset migkit:add-trigger
-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_posts_updated_at
    BEFORE UPDATE ON posts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
EOF

    # Update master changelog
    cat > "$CHANGELOG_DIR/changelog.json" << 'EOF'
{
  "databaseChangeLog": [
    {
      "include": {
        "file": "001-initial-schema.sql",
        "relativeToChangelogFile": true
      }
    },
    {
      "include": {
        "file": "002-sql-operations.sql",
        "relativeToChangelogFile": true
      }
    }
  ]
}
EOF

    # Apply the new changeset
    if docker compose -f test/docker-compose.yaml run --rm -e LIQ_DB_HOST=postgres-test -e LIQ_DB_USER=testuser -e LIQ_DB_PASSWORD=testpass -e LIQ_DB_NAME="$TEST_DB" liquibase-test --update; then
        print_success "SQL operations changeset applied successfully"
        return 0
    else
        print_error "SQL operations changeset application failed"
        return 1
    fi
}

# Test 5: Test rollback by count (3 levels)
test_rollback_by_count() {
    print_status "Testing rollback by count (3 levels)..."
    
    # Rollback 3 changesets
    if docker compose -f test/docker-compose.yaml run --rm -e LIQ_DB_HOST=postgres-test -e LIQ_DB_USER=testuser -e LIQ_DB_PASSWORD=testpass -e LIQ_DB_NAME="$TEST_DB" liquibase-test --rollback 3; then
        print_success "Rollback by count (3 levels) successful"
        return 0
    else
        print_error "Rollback by count (3 levels) failed"
        return 1
    fi
}

# Test 6: Test rollback to changeset
test_rollback_to_changeset() {
    print_status "Testing rollback to specific changeset..."
    
    # Rollback to a specific changeset
    if docker compose -f test/docker-compose.yaml run --rm -e LIQ_DB_HOST=postgres-test -e LIQ_DB_USER=testuser -e LIQ_DB_PASSWORD=testpass -e LIQ_DB_NAME="$TEST_DB" liquibase-test --rollback-to-changeset "migkit:add-user-fields"; then
        print_success "Rollback to changeset successful"
        return 0
    else
        print_error "Rollback to changeset failed"
        return 1
    fi
}

# Test 7: Test rollback all
test_rollback_all() {
    print_status "Testing rollback all..."
    
    if docker compose -f test/docker-compose.yaml run --rm -e LIQ_DB_HOST=postgres-test -e LIQ_DB_USER=testuser -e LIQ_DB_PASSWORD=testpass -e LIQ_DB_NAME="$TEST_DB" liquibase-test --rollback-all; then
        print_success "Rollback all successful"
        return 0
    else
        print_error "Rollback all failed"
        return 1
    fi
}

# Test 8: Test migration status
test_migration_status() {
    print_status "Testing migration status..."
    
    if docker compose -f test/docker-compose.yaml run --rm -e LIQ_DB_HOST=postgres-test -e LIQ_DB_USER=testuser -e LIQ_DB_PASSWORD=testpass -e LIQ_DB_NAME="$TEST_DB" liquibase-test --status; then
        print_success "Migration status check successful"
        return 0
    else
        print_error "Migration status check failed"
        return 1
    fi
}

# Test 9: Test rollback to date
test_rollback_to_date() {
    print_status "Testing rollback to specific date..."
    
    # Rollback to a specific date (yesterday)
    local yesterday=$(date -d "yesterday" +%Y-%m-%d)
    if docker compose -f test/docker-compose.yaml run --rm -e LIQ_DB_HOST=postgres-test -e LIQ_DB_USER=testuser -e LIQ_DB_PASSWORD=testpass -e LIQ_DB_NAME="$TEST_DB" liquibase-test --rollback-to-date "$yesterday"; then
        print_success "Rollback to date successful"
        return 0
    else
        print_error "Rollback to date failed"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    print_status "Starting Comprehensive Liquibase SQL Migration Test Suite..."
    echo "================================================"
    
    # Setup
    setup_test_environment
    
    # Run tests in the correct order
    run_test "Generate Initial Changelog" test_generate_initial_changelog
    run_test "Apply Changelog" test_apply_changelog
    run_test "Liquibase Initialization" test_liquibase_init
    run_test "SQL Operations" test_sql_operations
    run_test "Migration Status" test_migration_status
    run_test "Rollback by Count (3 levels)" test_rollback_by_count
    run_test "Rollback to Changeset" test_rollback_to_changeset
    run_test "Rollback to Date" test_rollback_to_date
    run_test "Rollback All" test_rollback_all
    
    # Print results
    echo "================================================"
    print_status "SQL Migration Test Results Summary:"
    print_success "Tests Passed: $TESTS_PASSED"
    if [ $TESTS_FAILED -gt 0 ]; then
        print_error "Tests Failed: $TESTS_FAILED"
    fi
    print_status "Total Tests: $TOTAL_TESTS"
    
    # Cleanup
    cleanup
    
    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "All SQL migration tests passed! ✅"
        exit 0
    else
        print_error "Some SQL migration tests failed! ❌"
        exit 1
    fi
}

# Cleanup between tests
cleanup_between_tests() {
    # Clean up any existing test databases to prevent conflicts
    docker compose -f test/docker-compose.yaml exec -T postgres-test psql -U testuser -d postgres -c "DROP DATABASE IF EXISTS $TEST_DB; DROP DATABASE IF EXISTS $REF_DB;" 2>/dev/null || true
    # Recreate them
    docker compose -f test/docker-compose.yaml exec -T postgres-test psql -U testuser -d postgres -c "CREATE DATABASE $TEST_DB;" 2>/dev/null || true
    docker compose -f test/docker-compose.yaml exec -T postgres-test psql -U testuser -d postgres -c "CREATE DATABASE $REF_DB;" 2>/dev/null || true
}

# Helper function to run individual tests
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    print_status "Running: $test_name"
    
    # Clean up before each test (except the first one)
    # Temporarily disabled to debug database issues
    # if [ $TOTAL_TESTS -gt 1 ]; then
    #     cleanup_between_tests
    # fi
    
    if $test_function; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        print_success "$test_name passed"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        print_error "$test_name failed"
    fi
    
    echo "----------------------------------------"
}

# Handle script arguments
case "${1:-}" in
    --cleanup)
        cleanup
        exit 0
        ;;
    --help)
        echo "Usage: $0 [--cleanup|--help]"
        echo "  --cleanup: Clean up test environment"
        echo "  --help: Show this help message"
        echo "  (no args): Run all tests"
        exit 0
        ;;
    *)
        run_all_tests
        ;;
esac

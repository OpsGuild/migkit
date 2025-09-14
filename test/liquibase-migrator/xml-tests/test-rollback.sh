#!/bin/bash

# Comprehensive Liquibase XML Migration Test Suite
# Tests all Liquibase migrator commands and XML operations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_DB="testdb_xml"
REF_DB="testdb_ref_xml"
CHANGELOG_DIR="../sandbox/liquibase-migrator/changelog-xml"
SCHEMA_DIR="../sandbox/liquibase-migrator/schema-xml"
TEST_RESULTS_DIR="../sandbox/liquibase-migrator/results-xml"

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

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Function to clean changelogs
clean_changelogs() {
    print_info "Cleaning changelogs before running tests..."
    
    local changelog_dir="../../sandbox/liquibase-migrator/changelog"
    
    mkdir -p "$changelog_dir"
    
    find "$changelog_dir" -name "changelog-*.sql" -type f -delete 2>/dev/null || true
    find "$changelog_dir" -name "changelog-*.xml" -type f -delete 2>/dev/null || true
    find "$changelog_dir" -name "changelog-initial.sql" -type f -delete 2>/dev/null || true
    find "$changelog_dir" -name "changelog-initial.xml" -type f -delete 2>/dev/null || true
    
    # Always reset the XML master changelog for XML tests
    echo '<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-latest.xsd">
</databaseChangeLog>' > "$changelog_dir/changelog.xml"
    
    local remaining_files=$(find "$changelog_dir" -name "changelog-*.sql" -type f | wc -l)
    if [ "$remaining_files" -eq 0 ]; then
        print_success "Changelogs cleaned - no generated SQL files remain"
        if grep -q "<databaseChangeLog" "$changelog_dir/changelog.xml" && ! grep -q "<changeSet" "$changelog_dir/changelog.xml"; then
            print_success "changelog.xml properly reset to empty state"
        else
            print_error "changelog.xml was not properly reset!"
            cat "$changelog_dir/changelog.xml"
        fi
    else
        print_error "Warning: $remaining_files SQL files still exist after cleanup"
        find "$changelog_dir" -name "changelog-*.sql" -type f
    fi
}

# Cleanup function
cleanup() {
    print_status "Cleaning up test environment..."
    docker compose -f ../../docker-compose.yaml down -v >/dev/null 2>&1 || true
    rm -rf "$CHANGELOG_DIR" "$SCHEMA_DIR" "$TEST_RESULTS_DIR" >/dev/null 2>&1 || true
}

# Clean changelogs function
clean_changelogs() {
    print_status "Cleaning changelogs..."
    mkdir -p ../sandbox/liquibase-migrator/changelog
    # Remove generated changelog files but keep changelog.json and any legitimate test files
    find ../sandbox/liquibase-migrator/changelog -name "changelog-*.sql" -type f -delete 2>/dev/null || true
    find ../sandbox/liquibase-migrator/changelog -name "changelog-initial.sql" -type f -delete 2>/dev/null || true
    echo '{"databaseChangeLog": []}' > ../sandbox/liquibase-migrator/changelog/changelog.json
}

# Setup test environment
setup_test_environment() {
    print_status "Setting up XML migration test environment..."
    
    # Clean changelogs before starting tests
    clean_changelogs
    
    # Create test directories
    mkdir -p "$CHANGELOG_DIR" "$SCHEMA_DIR" "$TEST_RESULTS_DIR"
    
    # Start services
    print_status "Starting test services..."
    docker compose -f ../../docker-compose.yaml up -d postgres-test
    
    # Wait for database to be ready
    print_status "Waiting for database to be ready..."
    until docker compose -f ../../docker-compose.yaml exec postgres-test pg_isready -U testuser -d postgres >/dev/null 2>&1; do
        sleep 1
    done
    
    # Create test databases (only if they don't exist)
    docker compose -f ../../docker-compose.yaml exec -T postgres-test psql -U testuser -d postgres -c "CREATE DATABASE $TEST_DB;" 2>/dev/null || true
    docker compose -f ../../docker-compose.yaml exec -T postgres-test psql -U testuser -d postgres -c "CREATE DATABASE $REF_DB;" 2>/dev/null || true
    
    print_success "Test environment setup complete"
}

# Test 1: Basic Liquibase initialization
test_liquibase_init() {
    print_status "Testing Liquibase initialization..."
    
    # Test --init command
    if docker compose -f ../../docker-compose.yaml run --rm  -e CHANGELOG_FORMAT=xml liquibase-test --init; then
        print_success "Liquibase initialization successful"
        return 0
    else
        print_error "Liquibase initialization failed"
        return 1
    fi
}

# Test 2: Generate initial changelog from reference database
test_generate_initial_changelog() {
    print_status "Testing initial XML changelog generation..."
    
    # Create test data that matches the existing init-db.sql schema
    cat > "../sandbox/liquibase-migrator/schema/test-data.sql" << 'EOF'
-- Test data for XML migration testing
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

    # Note: Schema and data will be applied by the migrate script using REFERENCE_SCHEMA
    
    # Generate changelog (will auto-discover all SQL files in /liquibase/schema/)
    if docker compose -f ../../docker-compose.yaml run --rm  -e CHANGELOG_FORMAT=xml -e MAIN_DB_NAME=testdb_xml -e REF_DB_NAME=testdb_ref_xml liquibase-test --generate; then
        print_success "Initial XML changelog generation successful"
        return 0
    else
        print_error "Initial XML changelog generation failed"
        return 1
    fi
}

# Test 3: Apply generated changelog
test_apply_changelog() {
    print_status "Testing XML changelog application..."
    
    if docker compose -f ../../docker-compose.yaml run --rm  -e CHANGELOG_FORMAT=xml -e MAIN_DB_NAME=testdb_xml liquibase-test --update; then
        print_success "XML changelog application successful"
        return 0
    else
        print_error "XML changelog application failed"
        return 1
    fi
}

# Test 4: Test all XML operations with new changeset
test_xml_operations() {
    print_status "Testing comprehensive XML operations..."
    
    # Create a new XML changeset with various operations
    cat > "$CHANGELOG_DIR/002-xml-operations.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
                        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.3.xsd">

    <!-- Add new columns to products table -->
    <changeSet id="migkit:add-product-fields" author="migkit">
        <addColumn tableName="products">
            <column name="weight" type="DECIMAL(8,2)" remarks="Product weight in kg">
                <constraints nullable="true"/>
            </column>
            <column name="dimensions" type="VARCHAR(100)" remarks="Product dimensions (LxWxH)">
                <constraints nullable="true"/>
            </column>
            <column name="is_featured" type="BOOLEAN" defaultValueBoolean="false">
                <constraints nullable="false"/>
            </column>
        </addColumn>
    </changeSet>

    <!-- Create product reviews table -->
    <changeSet id="migkit:create-product-reviews" author="migkit">
        <createTable tableName="product_reviews">
            <column name="id" type="SERIAL" autoIncrement="true">
                <constraints primaryKey="true" nullable="false"/>
            </column>
            <column name="product_id" type="INTEGER">
                <constraints nullable="false" foreignKeyName="fk_product_reviews_product" referencedTableName="products" referencedColumnNames="id"/>
            </column>
            <column name="customer_id" type="INTEGER">
                <constraints nullable="false" foreignKeyName="fk_product_reviews_customer" referencedTableName="customers" referencedColumnNames="id"/>
            </column>
            <column name="rating" type="INTEGER">
                <constraints nullable="false"/>
            </column>
            <column name="review_text" type="TEXT">
                <constraints nullable="true"/>
            </column>
            <column name="created_at" type="TIMESTAMP" defaultValueComputed="CURRENT_TIMESTAMP">
                <constraints nullable="false"/>
            </column>
        </createTable>
        
        <addCheckConstraint tableName="product_reviews" constraintName="chk_rating_range" checkCondition="rating >= 1 AND rating <= 5"/>
        
        <createIndex tableName="product_reviews" indexName="idx_product_reviews_product">
            <column name="product_id"/>
        </createIndex>
        
        <createIndex tableName="product_reviews" indexName="idx_product_reviews_customer">
            <column name="customer_id"/>
        </createIndex>
    </changeSet>

    <!-- Add new columns to orders table -->
    <changeSet id="migkit:add-order-fields" author="migkit">
        <addColumn tableName="orders">
            <column name="shipping_address" type="TEXT">
                <constraints nullable="true"/>
            </column>
            <column name="billing_address" type="TEXT">
                <constraints nullable="true"/>
            </column>
            <column name="payment_method" type="VARCHAR(50)">
                <constraints nullable="true"/>
            </column>
            <column name="tracking_number" type="VARCHAR(100)">
                <constraints nullable="true"/>
            </column>
        </addColumn>
        
        <addCheckConstraint tableName="orders" constraintName="chk_status_values" checkCondition="status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')"/>
    </changeSet>

    <!-- Create inventory table -->
    <changeSet id="migkit:create-inventory" author="migkit">
        <createTable tableName="inventory">
            <column name="id" type="SERIAL" autoIncrement="true">
                <constraints primaryKey="true" nullable="false"/>
            </column>
            <column name="product_id" type="INTEGER">
                <constraints nullable="false" foreignKeyName="fk_inventory_product" referencedTableName="products" referencedColumnNames="id"/>
            </column>
            <column name="warehouse_location" type="VARCHAR(100)">
                <constraints nullable="false"/>
            </column>
            <column name="quantity_available" type="INTEGER">
                <constraints nullable="false"/>
            </column>
            <column name="quantity_reserved" type="INTEGER" defaultValueNumeric="0">
                <constraints nullable="false"/>
            </column>
            <column name="reorder_level" type="INTEGER" defaultValueNumeric="10">
                <constraints nullable="false"/>
            </column>
            <column name="last_updated" type="TIMESTAMP" defaultValueComputed="CURRENT_TIMESTAMP">
                <constraints nullable="false"/>
            </column>
        </createTable>
        
        <addCheckConstraint tableName="inventory" constraintName="chk_quantity_positive" checkCondition="quantity_available >= 0 AND quantity_reserved >= 0"/>
        
        <createUniqueConstraint tableName="inventory" constraintName="uk_inventory_product_warehouse" columnNames="product_id, warehouse_location"/>
    </changeSet>

    <!-- Create promotions table -->
    <changeSet id="migkit:create-promotions" author="migkit">
        <createTable tableName="promotions">
            <column name="id" type="SERIAL" autoIncrement="true">
                <constraints primaryKey="true" nullable="false"/>
            </column>
            <column name="name" type="VARCHAR(200)">
                <constraints nullable="false"/>
            </column>
            <column name="description" type="TEXT">
                <constraints nullable="true"/>
            </column>
            <column name="discount_type" type="VARCHAR(20)">
                <constraints nullable="false"/>
            </column>
            <column name="discount_value" type="DECIMAL(10,2)">
                <constraints nullable="false"/>
            </column>
            <column name="start_date" type="DATE">
                <constraints nullable="false"/>
            </column>
            <column name="end_date" type="DATE">
                <constraints nullable="false"/>
            </column>
            <column name="is_active" type="BOOLEAN" defaultValueBoolean="true">
                <constraints nullable="false"/>
            </column>
            <column name="created_at" type="TIMESTAMP" defaultValueComputed="CURRENT_TIMESTAMP">
                <constraints nullable="false"/>
            </column>
        </createTable>
        
        <addCheckConstraint tableName="promotions" constraintName="chk_discount_type" checkCondition="discount_type IN ('percentage', 'fixed_amount')"/>
        <addCheckConstraint tableName="promotions" constraintName="chk_discount_value" checkCondition="discount_value > 0"/>
        <addCheckConstraint tableName="promotions" constraintName="chk_date_range" checkCondition="end_date > start_date"/>
    </changeSet>

    <!-- Insert test data -->
    <changeSet id="migkit:insert-test-data" author="migkit">
        <insert tableName="product_reviews">
            <column name="product_id" valueNumeric="1"/>
            <column name="customer_id" valueNumeric="1"/>
            <column name="rating" valueNumeric="5"/>
            <column name="review_text" value="Excellent laptop, very fast and reliable!"/>
        </insert>
        
        <insert tableName="product_reviews">
            <column name="product_id" valueNumeric="1"/>
            <column name="customer_id" valueNumeric="2"/>
            <column name="rating" valueNumeric="4"/>
            <column name="review_text" value="Good laptop, but battery life could be better."/>
        </insert>
        
        <insert tableName="inventory">
            <column name="product_id" valueNumeric="1"/>
            <column name="warehouse_location" value="Main Warehouse"/>
            <column name="quantity_available" valueNumeric="50"/>
            <column name="reorder_level" valueNumeric="10"/>
        </insert>
        
        <insert tableName="inventory">
            <column name="product_id" valueNumeric="2"/>
            <column name="warehouse_location" value="Main Warehouse"/>
            <column name="quantity_available" valueNumeric="200"/>
            <column name="reorder_level" valueNumeric="25"/>
        </insert>
        
        <insert tableName="promotions">
            <column name="name" value="Summer Sale"/>
            <column name="description" value="20% off all electronics"/>
            <column name="discount_type" value="percentage"/>
            <column name="discount_value" valueNumeric="20.00"/>
            <column name="start_date" valueDate="2024-06-01"/>
            <column name="end_date" valueDate="2024-08-31"/>
        </insert>
    </changeSet>

    <!-- Create view -->
    <changeSet id="migkit:create-product-summary-view" author="migkit">
        <sql>
            CREATE VIEW product_summary AS
            SELECT 
                p.id,
                p.name,
                p.price,
                pc.name as category_name,
                COALESCE(AVG(pr.rating), 0) as average_rating,
                COUNT(pr.id) as review_count,
                COALESCE(i.quantity_available, 0) as stock_quantity,
                p.is_featured,
                p.created_at
            FROM products p
            LEFT JOIN product_categories pc ON p.category_id = pc.id
            LEFT JOIN product_reviews pr ON p.id = pr.product_id
            LEFT JOIN inventory i ON p.id = i.product_id
            GROUP BY p.id, p.name, p.price, pc.name, i.quantity_available, p.is_featured, p.created_at;
        </sql>
    </changeSet>

    <!-- Create stored procedure -->
    <changeSet id="migkit:create-update-inventory-proc" author="migkit">
        <sql>
            CREATE OR REPLACE FUNCTION update_inventory(
                p_product_id INTEGER,
                p_quantity_change INTEGER,
                p_warehouse VARCHAR(100)
            ) RETURNS BOOLEAN AS $$
            DECLARE
                current_quantity INTEGER;
            BEGIN
                -- Get current quantity
                SELECT quantity_available INTO current_quantity
                FROM inventory
                WHERE product_id = p_product_id AND warehouse_location = p_warehouse;
                
                -- Check if we have enough stock
                IF current_quantity + p_quantity_change < 0 THEN
                    RETURN FALSE;
                END IF;
                
                -- Update inventory
                UPDATE inventory
                SET quantity_available = quantity_available + p_quantity_change,
                    last_updated = CURRENT_TIMESTAMP
                WHERE product_id = p_product_id AND warehouse_location = p_warehouse;
                
                RETURN TRUE;
            END;
            $$ LANGUAGE plpgsql;
        </sql>
    </changeSet>

    <!-- Create trigger -->
    <changeSet id="migkit:create-order-total-trigger" author="migkit">
        <sql>
            CREATE OR REPLACE FUNCTION calculate_order_total()
            RETURNS TRIGGER AS $$
            BEGIN
                UPDATE orders
                SET total_amount = (
                    SELECT COALESCE(SUM(total_price), 0)
                    FROM order_items
                    WHERE order_id = NEW.order_id
                )
                WHERE id = NEW.order_id;
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
        </sql>
        
        <sql>
            CREATE TRIGGER trigger_calculate_order_total
                AFTER INSERT OR UPDATE OR DELETE ON order_items
                FOR EACH ROW
                EXECUTE FUNCTION calculate_order_total();
        </sql>
    </changeSet>

    <!-- Add constraints -->
    <changeSet id="migkit:add-constraints" author="migkit">
        <addCheckConstraint tableName="products" constraintName="chk_price_positive" checkCondition="price > 0"/>
        <addCheckConstraint tableName="orders" constraintName="chk_total_amount_positive" checkCondition="total_amount >= 0"/>
        <addCheckConstraint tableName="order_items" constraintName="chk_quantity_positive" checkCondition="quantity > 0"/>
    </changeSet>

    <!-- Update existing data -->
    <changeSet id="migkit:update-existing-data" author="migkit">
        <update tableName="products">
            <column name="weight" valueNumeric="2.5"/>
            <column name="dimensions" value="15x10x1"/>
            <column name="is_featured" valueBoolean="true"/>
            <where>id = 1</where>
        </update>
        
        <update tableName="products">
            <column name="weight" valueNumeric="0.1"/>
            <column name="dimensions" value="12x6x3"/>
            <where>id = 2</where>
        </update>
        
        <update tableName="orders">
            <column name="shipping_address" value="123 Main St, New York, NY 10001"/>
            <column name="billing_address" value="123 Main St, New York, NY 10001"/>
            <column name="payment_method" value="credit_card"/>
            <where>status = 'delivered'</where>
        </update>
    </changeSet>

</databaseChangeLog>
EOF

    # Update master changelog
    cat > "$CHANGELOG_DIR/changelog.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
                        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.3.xsd">

    <include file="001-initial-schema.xml" relativeToChangelogFile="true"/>
    <include file="002-xml-operations.xml" relativeToChangelogFile="true"/>

</databaseChangeLog>
EOF

    # Apply the new changeset
    if docker compose -f ../../docker-compose.yaml run --rm  -e CHANGELOG_FORMAT=xml -e MAIN_DB_NAME=testdb_xml liquibase-test --update; then
        print_success "XML operations changeset applied successfully"
        return 0
    else
        print_error "XML operations changeset application failed"
        return 1
    fi
}

# Test 5: Test rollback by count (3 levels)
test_rollback_by_count() {
    print_status "Testing rollback by count (3 levels)..."
    
    # Rollback 3 changesets
    if docker compose -f ../../docker-compose.yaml run --rm  -e CHANGELOG_FORMAT=xml -e MAIN_DB_NAME=testdb_xml liquibase-test --rollback 3; then
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
    if docker compose -f ../../docker-compose.yaml run --rm  -e CHANGELOG_FORMAT=xml -e MAIN_DB_NAME=testdb_xml liquibase-test --rollback-to-changeset "migkit:add-product-fields"; then
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
    
    if docker compose -f ../../docker-compose.yaml run --rm  -e CHANGELOG_FORMAT=xml -e MAIN_DB_NAME=testdb_xml liquibase-test --rollback-all; then
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
    
    if docker compose -f ../../docker-compose.yaml run --rm  -e CHANGELOG_FORMAT=xml -e MAIN_DB_NAME=testdb_xml liquibase-test --status; then
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
    if docker compose -f ../../docker-compose.yaml run --rm  -e CHANGELOG_FORMAT=xml -e MAIN_DB_NAME=testdb_xml liquibase-test --rollback-to-date "$yesterday"; then
        print_success "Rollback to date successful"
        return 0
    else
        print_error "Rollback to date failed"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    print_status "Starting Comprehensive Liquibase XML Migration Test Suite..."
    echo "================================================"
    
    # Setup
    setup_test_environment
    
    # Run tests
    run_test "Liquibase Initialization" test_liquibase_init
    run_test "Generate Initial Changelog" test_generate_initial_changelog
    run_test "Apply Changelog" test_apply_changelog
    run_test "XML Operations" test_xml_operations
    run_test "Migration Status" test_migration_status
    run_test "Rollback by Count (3 levels)" test_rollback_by_count
    run_test "Rollback to Changeset" test_rollback_to_changeset
    run_test "Rollback to Date" test_rollback_to_date
    run_test "Rollback All" test_rollback_all
    
    # Print results
    echo "================================================"
    print_status "XML Migration Test Results Summary:"
    print_success "Tests Passed: $TESTS_PASSED"
    if [ $TESTS_FAILED -gt 0 ]; then
        print_error "Tests Failed: $TESTS_FAILED"
    fi
    print_status "Total Tests: $TOTAL_TESTS"
    
    # Cleanup
    cleanup
    
    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "All XML migration tests passed! ✅"
        exit 0
    else
        print_error "Some XML migration tests failed! ❌"
        exit 1
    fi
}

# No cleanup between tests needed - changelogs should persist across tests

# Helper function to run individual tests
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    print_status "Running: $test_name"
    
    # No cleanup needed between tests - changelogs should persist
    
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

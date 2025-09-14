# MigKit 🚀

A comprehensive database migration toolkit built on top of Liquibase, designed to simplify database schema management across multiple database types with automated changelog generation and cross-database compatibility.

## Overview

MigKit is a Docker-based migration solution that provides:
- **Multi-database support**: PostgreSQL, MySQL, MariaDB, and SQLite
- **Automated changelog generation**: Compares reference and target databases to generate migration scripts
- **Cross-database compatibility**: Generate migrations for one database type from another
- **Comprehensive testing**: Full test suite with multiple database scenarios
- **Docker-first approach**: Easy deployment and consistent environments

## Features

### 🗄️ Multi-Database Support
- **PostgreSQL** - Full support with advanced features
- **MySQL** - Complete compatibility including triggers and functions
- **MariaDB** - Native support with MySQL compatibility
- **SQLite** - Lightweight database support for development and testing

### 🔄 Migration Management
- **Automated changelog generation** - Compare schemas and auto-generate migration scripts
- **SQL and XML formats** - Support for both Liquibase changelog formats
- **Rollback capabilities** - Full rollback support with multiple strategies
- **Schema validation** - Built-in validation and constraint checking

### 🐳 Docker Integration
- **Containerized environment** - Consistent migration environment across platforms
- **Multi-database testing** - Test against multiple database types simultaneously
- **Easy deployment** - Simple Docker Compose setup for development and testing

### 🧪 Comprehensive Testing
- **Cross-database tests** - Validate migrations across different database types
- **Rollback testing** - Ensure rollback operations work correctly
- **Scenario testing** - Test complex migration scenarios
- **Automated test suite** - Full CI/CD integration

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Git

### 1. Clone the Repository
```bash
git clone https://github.com/migkit/migkit.git
cd migkit
```

### 2. Start Test Environment
```bash
# Start PostgreSQL test database
docker-compose --profile test up -d postgres-test

# Or start all test databases
docker-compose --profile test up -d
```

### 3. Run Migrations
```bash
# Build the migrator image
docker build -t migkit/liquibase-migrator ./liquibase-migrator

# Run a basic migration
docker run --rm \
  -e MAIN_DB_TYPE=postgresql \
  -e MAIN_DB_HOST=postgres-test \
  -e MAIN_DB_USER=testuser \
  -e MAIN_DB_PASSWORD=testpass \
  -e MAIN_DB_NAME=testdb \
  -e REF_DB_TYPE=postgresql \
  -e REF_DB_HOST=postgres-test \
  -e REF_DB_USER=testuser \
  -e REF_DB_PASSWORD=testpass \
  -e REF_DB_NAME=testdb_ref \
  --network migkit_default \
  migkit/liquibase-migrator --init
```

## Usage

### Basic Commands

#### Initialize Database
```bash
migrate --init
```
Creates the initial database schema and sets up Liquibase tracking tables.

#### Generate Changelog
```bash
migrate --generate
```
Compares the reference database with the target database and generates a new changelog file.

#### Apply Migrations
```bash
migrate --update
```
Applies pending migrations to the target database.

#### Generate and Apply
```bash
migrate --generate-and-update
```
Generates a new changelog and immediately applies it to the target database.

### Rollback Operations

#### Rollback by Count
```bash
migrate --rollback 3
```
Rolls back the last 3 changesets.

#### Rollback to Date
```bash
migrate --rollback-to-date 2024-01-15
```
Rolls back to a specific date.

#### Rollback to Changeset
```bash
migrate --rollback-to-changeset abc123
```
Rolls back to a specific changeset ID.

#### Rollback All
```bash
migrate --rollback-all
```
Rolls back all changes.

### Status and Information
```bash
migrate --status
```
Shows the current status of the database and pending migrations.

## Configuration

### Environment Variables

#### Main Database Configuration
```bash
MAIN_DB_TYPE=postgresql          # Database type (postgresql, mysql, mariadb, sqlite)
MAIN_DB_HOST=localhost           # Database host
MAIN_DB_PORT=5432               # Database port
MAIN_DB_USER=username           # Database username
MAIN_DB_PASSWORD=password       # Database password
MAIN_DB_NAME=database_name      # Database name
```

#### Reference Database Configuration
```bash
REF_DB_TYPE=postgresql          # Reference database type
REF_DB_HOST=localhost           # Reference database host
REF_DB_PORT=5432               # Reference database port
REF_DB_USER=username           # Reference database username
REF_DB_PASSWORD=password       # Reference database password
REF_DB_NAME=reference_db       # Reference database name
```

#### Migration Configuration
```bash
CHANGELOG_FORMAT=sql            # Changelog format (sql or xml)
SCHEMA_SCRIPTS=/path/to/scripts # Comma-separated list of schema scripts
```

### Docker Compose Configuration

The project includes a comprehensive `docker-compose.yaml` with test databases for all supported types:

- **PostgreSQL** (port 5433)
- **MySQL** (port 3307)
- **MariaDB** (port 3308)
- **SQLite** (file-based)

## Project Structure

```
migkit/
├── liquibase-migrator/          # Main migrator Docker image
│   ├── Dockerfile              # Docker configuration
│   ├── scripts/                # Migration scripts
│   │   ├── migrate.sh          # Main migration script
│   │   ├── rollback-sql.sh     # SQL rollback utilities
│   │   └── rollback-xml.sh     # XML rollback utilities
│   ├── changelog-schema/       # Default changelog templates
│   └── liquibase-default.properties
├── sandbox/                    # Development and testing schemas
│   └── liquibase-migrator/
│       ├── schema/             # Database schemas for each type
│       │   ├── postgresql/
│       │   ├── mysql/
│       │   ├── mariadb/
│       │   └── sqlite/
│       └── changelog/          # Generated changelogs
├── test/                       # Test suite
│   └── liquibase-migrator/
│       ├── multi-db-tests/     # Cross-database tests
│       ├── sql-tests/          # SQL-specific tests
│       └── xml-tests/          # XML-specific tests
└── docker-compose.yaml         # Test environment setup
```

## Testing

### Run All Tests
```bash
./test.sh
```

### Run Specific Test Suites
```bash
# SQL migration tests
cd test/liquibase-migrator
bash sql-tests/test-sql.sh

# Multi-database tests
bash multi-db-tests/test-multi-db.sh

# Rollback tests
bash sql-tests/test-rollbacks.sh
```

### Test Coverage
The test suite includes:
- **SQL Migration Tests** - Basic migration functionality
- **XML Migration Tests** - XML-based changelog support
- **Rollback Tests** - All rollback scenarios
- **Multi-Database Tests** - Cross-database compatibility
- **Scenario Tests** - Complex migration scenarios
- **Version Tests** - Version management and tracking

## Advanced Usage

### Custom Schema Scripts
You can specify custom schema scripts using the `SCHEMA_SCRIPTS` environment variable:

```bash
export SCHEMA_SCRIPTS="/liquibase/schema/postgresql/00-init-db.sql,/liquibase/schema/postgresql/01-init-data.sql"
```

### Cross-Database Migrations
Generate migrations for one database type from another:

```bash
# Generate PostgreSQL migrations from MySQL reference
export MAIN_DB_TYPE=postgresql
export REF_DB_TYPE=mysql
migrate --generate-and-update
```

### Direct Liquibase Access
Access Liquibase commands directly:

```bash
migrate liquibase status
migrate liquibase history
migrate liquibase validate
```

## Development

### Building the Image
```bash
docker build -t migkit/liquibase-migrator ./liquibase-migrator
```

### Running in Development Mode
```bash
docker run -it --rm \
  -v $(pwd)/sandbox/liquibase-migrator/schema:/liquibase/schema \
  -v $(pwd)/sandbox/liquibase-migrator/changelog:/liquibase/changelog \
  migkit/liquibase-migrator --shell
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/migkit/migkit/issues)
- **Discussions**: [GitHub Discussions](https://github.com/migkit/migkit/discussions)
- **Documentation**: [Wiki](https://github.com/migkit/migkit/wiki)

## Changelog

### v0.1.0
- Initial release
- Multi-database support (PostgreSQL, MySQL, MariaDB, SQLite)
- Automated changelog generation
- Comprehensive test suite
- Docker integration
- Rollback capabilities

---

**MigKit** - Making database migrations simple and reliable across all platforms. 🚀

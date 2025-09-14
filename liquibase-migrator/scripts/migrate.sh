#!/bin/bash

set -e

# Configuration
CHANGELOG_FORMAT=${CHANGELOG_FORMAT:-sql}
CHANGELOG_DIR=${CHANGELOG_DIR:-/liquibase/changelog}
SCHEMA_DIR=${SCHEMA_DIR:-/liquibase/schema}
DB_TYPE_FOR_CHANGELOG=${MAIN_DB_TYPE:-postgresql}
DB_TYPE_FOR_CHANGELOG=$(echo "$DB_TYPE_FOR_CHANGELOG" | tr '[:upper:]' '[:lower:]')

INIT_CHANGELOG=${INIT_CHANGELOG:-changelog-initial.${DB_TYPE_FOR_CHANGELOG}.${CHANGELOG_FORMAT:-sql}}
if [ "$CHANGELOG_FORMAT" = "sql" ]; then
  MASTER_CHANGELOG=${MASTER_CHANGELOG:-$CHANGELOG_DIR/changelog.json}
  CURRENT_CHANGELOG=changelog-$(date +%Y%m%d-%H%M%S).${DB_TYPE_FOR_CHANGELOG}.sql
elif [ "$CHANGELOG_FORMAT" = "xml" ]; then
  MASTER_CHANGELOG=${MASTER_CHANGELOG:-$CHANGELOG_DIR/changelog.xml}
  CURRENT_CHANGELOG=changelog-$(date +%Y%m%d-%H%M%S).${DB_TYPE_FOR_CHANGELOG}.xml
else
  echo "❌ Unsupported CHANGELOG_FORMAT: $CHANGELOG_FORMAT"
  exit 1
fi



# Check if Liquibase is installed (skip for help/status commands)
if ! command -v liquibase &>/dev/null; then
	# Allow help and status commands to work without Liquibase
	if [[ "$1" != "--help" && "$1" != "-h" && "$1" != "--status" ]]; then
		echo "❌ Liquibase not found. Make sure it's installed and in PATH."
		exit 1
	fi
fi

RUN_GENERATE=true
RUN_UPDATE=true
INIT=false
DROP_DB=false
ROLLBACK_COUNT=0
ROLLBACK_TO_DATE=""
ROLLBACK_TO_CHANGESET=""
ROLLBACK_TO_TAG=""
ROLLBACK_MODE=false
SCRIPTS=()

validate_env_vars() {
	local required_vars=("MAIN_DB_TYPE" "MAIN_DB_HOST" "MAIN_DB_USER" "MAIN_DB_NAME" "REF_DB_TYPE" "REF_DB_HOST" "REF_DB_USER" "REF_DB_NAME")
	local missing_vars=()
	
	for var in "${required_vars[@]}"; do
		if [ -z "${!var}" ]; then
			missing_vars+=("$var")
		fi
	done
	
	if [ ${#missing_vars[@]} -gt 0 ]; then
		echo "❌ Missing required environment variables: ${missing_vars[*]}"
		exit 1
	fi
	
	# Set defaults for optional variables
	MAIN_DB_PASSWORD=${MAIN_DB_PASSWORD:-""}
	MAIN_DB_PORT=${MAIN_DB_PORT:-5432}
	REF_DB_PASSWORD=${REF_DB_PASSWORD:-""}
	REF_DB_PORT=${REF_DB_PORT:-5432}
	CHANGELOG_FORMAT=${CHANGELOG_FORMAT:-sql}
}

# Build database connection string based on type
build_db_url() {
	local db_type=$1
	local db_host=$2
	local db_port=$3
	local db_name=$4
	
	case "$db_type" in
		postgresql|postgres)
			echo "jdbc:postgresql://$db_host:$db_port/$db_name"
			;;
		mysql)
			echo "jdbc:mysql://$db_host:$db_port/$db_name"
			;;
		mariadb)
			echo "jdbc:mariadb://$db_host:$db_port/$db_name"
			;;
		oracle)
			echo "jdbc:oracle:thin:@$db_host:$db_port:$db_name"
			;;
		sqlserver|mssql)
			echo "jdbc:sqlserver://$db_host:$db_port;databaseName=$db_name"
			;;
		h2)
			echo "jdbc:h2:tcp://$db_host:$db_port/$db_name"
			;;
		sqlite)
			echo "jdbc:sqlite:$db_host/$db_name.db"
			;;
		*)
			echo "jdbc:$db_type://$db_host:$db_port/$db_name"
			;;
	esac
}


# Set global Liquibase environment variables
set_liquibase_env() {
	export LIQUIBASE_COMMAND_URL="$(build_db_url "$MAIN_DB_TYPE" "$MAIN_DB_HOST" "$MAIN_DB_PORT" "$MAIN_DB_NAME")"
	export LIQUIBASE_COMMAND_USERNAME="$MAIN_DB_USER"
	export LIQUIBASE_COMMAND_PASSWORD="$MAIN_DB_PASSWORD"
	if [ -n "$MAIN_DB_DRIVER" ]; then
		export LIQUIBASE_COMMAND_DRIVER="$MAIN_DB_DRIVER"
	fi
	export LIQUIBASE_COMMAND_REFERENCE_URL="$(build_db_url "$REF_DB_TYPE" "$REF_DB_HOST" "$REF_DB_PORT" "$REF_DB_NAME")"
	export LIQUIBASE_COMMAND_REFERENCE_USERNAME="$REF_DB_USER"
	export LIQUIBASE_COMMAND_REFERENCE_PASSWORD="$REF_DB_PASSWORD"
	if [ -n "$REF_DB_DRIVER" ]; then
		export LIQUIBASE_COMMAND_REFERENCE_DRIVER="$REF_DB_DRIVER"
	fi
}

# Set Liquibase environment variables for reference database
set_ref_liquibase_env() {
	export LIQUIBASE_COMMAND_URL="$(build_db_url "$REF_DB_TYPE" "$REF_DB_HOST" "$REF_DB_PORT" "$REF_DB_NAME")"
	export LIQUIBASE_COMMAND_USERNAME="$REF_DB_USER"
	export LIQUIBASE_COMMAND_PASSWORD="$REF_DB_PASSWORD"
	if [ -n "$REF_DB_DRIVER" ]; then
		export LIQUIBASE_COMMAND_DRIVER="$REF_DB_DRIVER"
	fi
}

# Discover schema scripts
discover_schema_scripts() {
	if [ -n "$REFERENCE_SCHEMA" ]; then
		# Single script override
		SCRIPTS=("$REFERENCE_SCHEMA")
	elif [ -n "$SCHEMA_SCRIPTS" ]; then
		# Parse comma-separated list of scripts
		IFS=',' read -ra SCRIPTS <<< "$SCHEMA_SCRIPTS"
	else
		# Auto-discover all SQL files in schema directory
		if [ -d "$SCHEMA_DIR" ]; then
			while IFS= read -r -d '' file; do
				SCRIPTS+=("$file")
			done < <(find "$SCHEMA_DIR" -name "*.sql" -type f -print0 | sort -z)
		fi
		
		# If no SQL files found, fall back to default
		if [ ${#SCRIPTS[@]} -eq 0 ]; then
			SCRIPTS=("$SCHEMA_DIR/init-db.sql")
		fi
	fi
}

create_ref_db() {
	local db_host=$1
	local db_user=$2
	local db_password=$3
	local db_name=$4
	local db_type=$5
	
	echo "🏗️ Creating reference database $db_name..."
	
	case "$db_type" in
		postgresql)
			if PGPASSWORD="$db_password" psql -h "$db_host" -U "$db_user" -d "postgres" -c "CREATE DATABASE \"$db_name\";" &>/dev/null; then
				echo "✅ Reference database $db_name created successfully!"
			elif PGPASSWORD="$db_password" psql -h "$db_host" -U "$db_user" -d "$db_name" -c '\q' &>/dev/null; then
				echo "ℹ️ Reference database $db_name already exists."
			else
				echo "⚠️ Could not create or verify reference database $db_name. Will attempt to continue..."
			fi
			;;
		mysql|mariadb)
			if mysql -h "$db_host" -u "$db_user" -p"$db_password" -e "CREATE DATABASE IF NOT EXISTS $db_name;" &>/dev/null; then
				echo "✅ Reference database $db_name created successfully!"
			elif mysql -h "$db_host" -u "$db_user" -p"$db_password" -e "USE $db_name;" &>/dev/null; then
				echo "ℹ️ Reference database $db_name already exists."
			else
				echo "⚠️ Could not create or verify reference database $db_name. Will attempt to continue..."
			fi
			;;
		sqlite)
			if [ -f "/data/$db_name.db" ]; then
				echo "ℹ️ Reference database $db_name already exists."
			else
				echo "✅ Reference database $db_name created successfully!"
			fi
			;;
	esac
}

wait_for_db() {
	local db_host=$1
	local db_port=$2
	local db_user=$3
	local db_password=$4
	local db_name=$5
	local db_type=$6
	
	local RETRIES=20
	local WAIT=30

	echo "⏳ Waiting for $db_name to be ready..."

	for ((i = 1; i <= RETRIES; i++)); do
		local connection_success=false
		
		case "$db_type" in
			postgresql|postgres|mysql|mariadb|oracle|sqlserver|mssql|h2)
				if nc -z "$db_host" "$db_port" &>/dev/null; then
					connection_success=true
				fi
				;;
			sqlite)
				# For SQLite, just check if the database file exists or can be created
				# SQLite will create the file if it doesn't exist
				if [ -f "$db_host/$db_name.db" ] || touch "$db_host/$db_name.db" 2>/dev/null; then
					connection_success=true
				fi
				;;
		esac
		
		if [ "$connection_success" = true ]; then
			echo "✅ Database $db_name is ready!"
			return 0
		fi
		
		echo "  Attempt $i/$RETRIES: DB $db_name not ready yet, retrying in $WAITs..."
		sleep $WAIT
	done

	echo "❌ Database connection timed out after $((RETRIES * WAIT)) seconds."
	exit 1
}

run_sql_scripts_on_db() {
    local db_host=$1
    local db_user=$2
    local db_password=$3
    local db_name=$4
	local db_type=$5
    
    echo "📝 Running SQL scripts on database: $db_name"

    for script in "${SCRIPTS[@]}"; do
        if [ -f "$script" ]; then
            echo "  - Running $script on $db_name"
            case "$db_type" in
                postgresql)
                    PGPASSWORD="$db_password" psql \
                        -h "$db_host" \
                        -U "$db_user" \
                        -d "$db_name" \
                        -f "$script"
                    ;;
                mysql)
                    mysql -h "$db_host" \
                        -u "$db_user" \
                        -p"$db_password" \
                        "$db_name" < "$script"
                    ;;
                mariadb)
                    mysql -h "$db_host" \
                        -u "$db_user" \
                        -p"$db_password" \
                        "$db_name" < "$script"
                    ;;
                sqlite)
                    sqlite3 "/data/$db_name.db" < "$script"
                    ;;
            esac
        else
            echo "  ⚠️  Skipping missing script: $script"
        fi
    done
}

is_database_empty() {
    local db_host=$1
    local db_user=$2
    local db_password=$3
    local db_name=$4
	local db_type=$5
    
    local table_count=0
    case "$db_type" in
        "postgresql")
            table_count=$(PGPASSWORD="$db_password" psql -h "$db_host" -U "$db_user" -d "$db_name" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "0")
            ;;
        "mariadb"|"mysql")
            table_count=$(mysql -h "$db_host" -u "$db_user" -p"$db_password" "$db_name" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$db_name';" 2>/dev/null | tail -1 || echo "0")
            ;;
        "sqlite")
            table_count=$(sqlite3 "$db_name" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
            ;;
    esac
    
    [ "$table_count" -eq 0 ]
}

show_rollback_status() {
	echo "📊 Current database status:"
	liquibase status
	echo ""
}

rollback_by_count() {
	local count=$1
	echo "🔄 Rolling back $count changeset(s)..."
	
	if liquibase rollbackCount "$count"; then
		echo "✅ Rollback by count successful!"
		show_rollback_status
		return 0
	else
		echo "❌ Rollback by count failed!"
		return 1
	fi
}

rollback_to_date() {
	local target_date=$1
	echo "🔄 Rolling back to date: $target_date"
	
	# Convert date to ISO format with time if only date is provided
	if [[ "$target_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
		target_date="${target_date}T00:00:00"
	fi
	
	if liquibase rollback-to-date "$target_date"; then
		echo "✅ Rollback to date successful!"
		show_rollback_status
		return 0
	else
		echo "❌ Rollback to date failed!"
		return 1
	fi
}

rollback_to_changeset() {
	local changeset_id=$1
	echo "🔄 Rolling back to changeset: $changeset_id"
	echo "⚠️  Note: rollback-to-changeset requires Liquibase Pro features"
	echo "❌ Rollback to changeset failed - Pro feature not available!"
	return 1
}

rollback_to_tag() {
	local tag=$1
	echo "🔄 Rolling back to tag: $tag"
	
	if liquibase rollback-to-tag "$tag"; then
		echo "✅ Rollback to tag successful!"
		show_rollback_status
		return 0
	else
		echo "❌ Rollback to tag failed!"
		return 1
	fi
}

rollback_all() {
	echo "🔄 Rolling back all changes..."
	
	if liquibase rollbackCount 999999; then
		echo "✅ Rollback all successful!"
		show_rollback_status
		return 0
	else
		echo "❌ Rollback all failed!"
		return 1
	fi
}

generate_init_changelog() {
    if [ ! -f "$CHANGELOG_DIR/$INIT_CHANGELOG" ]; then
        if is_database_empty "$MAIN_DB_HOST" "$MAIN_DB_USER" "$MAIN_DB_PASSWORD" "$MAIN_DB_NAME" "$MAIN_DB_TYPE"; then
            echo "📋 Main database is empty, generating changelog from reference database..."

            run_sql_scripts_on_db "$REF_DB_HOST" "$REF_DB_USER" "$REF_DB_PASSWORD" "$REF_DB_NAME" "$REF_DB_TYPE"
            set_ref_liquibase_env
        else
            echo "📋 Main database has existing schema, generating changelog from current state..."
            set_liquibase_env
        fi

        # Build liquibase command based on database type
        # For MariaDB/MySQL, don't include schema/catalog names as they cause issues
        # For other databases, include them for proper schema management
        local liquibase_cmd="liquibase --changelog-file=\"$CHANGELOG_DIR/$INIT_CHANGELOG\" generateChangeLog"
        
        if [ "$MAIN_DB_TYPE" = "mariadb" ] || [ "$MAIN_DB_TYPE" = "mysql" ]; then
            # For MariaDB/MySQL, don't include schema/catalog to avoid database name prefixes
            liquibase_cmd="$liquibase_cmd --includeSchema=false --includeCatalog=false"
        else
            # For other databases (PostgreSQL, Oracle, etc.), include schema/catalog
            liquibase_cmd="$liquibase_cmd --includeSchema=true --includeTablespace=true --includeCatalog=true"
        fi

        eval $liquibase_cmd

        if [ -f "$CHANGELOG_DIR/$INIT_CHANGELOG" ]; then
            if [ "$CHANGELOG_FORMAT" = "xml" ]; then
                ./rollback-xml.sh "$CHANGELOG_DIR/$INIT_CHANGELOG"
            else
                ./rollback-sql.sh "$CHANGELOG_DIR/$INIT_CHANGELOG"
            fi
        fi
    else
        echo "⚠️ $INIT_CHANGELOG already exists. Skipping generation."
    fi

    include_changelog_if_valid "$INIT_CHANGELOG"
}


run_init() {
    echo "🚀 Initializing database changelog..."

    generate_init_changelog

    if is_database_empty "$MAIN_DB_HOST" "$MAIN_DB_USER" "$MAIN_DB_PASSWORD" "$MAIN_DB_NAME" "$MAIN_DB_TYPE"; then
        echo "📋 Applying initial changelog to main database..."
        set_liquibase_env
        liquibase update
    else
        echo "📋 Synchronizing changelog with current state..."
        set_liquibase_env
        liquibase changelogSync
    fi

    echo "✅ Initialization complete! Database schema is now version-controlled."
}


run_generate() {
    echo "🔄 Generating diff changelog..."
    
    # Check if initial changelog exists
    if [ ! -f "$CHANGELOG_DIR/$INIT_CHANGELOG" ]; then
        echo "⚠️ Initial changelog not found. Generating initial changelog first..."
        generate_init_changelog
        echo "✅ Initial changelog created. Generate operation complete."
        return 0
    fi
    
    # Initial changelog exists, proceed with diff generation
    create_ref_db "$REF_DB_HOST" "$REF_DB_USER" "$REF_DB_PASSWORD" "$REF_DB_NAME" "$REF_DB_TYPE"
	wait_for_db "$REF_DB_HOST" "$REF_DB_PORT" "$REF_DB_USER" "$REF_DB_PASSWORD" "$REF_DB_NAME" "$REF_DB_TYPE"
	run_sql_scripts_on_db "$REF_DB_HOST" "$REF_DB_USER" "$REF_DB_PASSWORD" "$REF_DB_NAME" "$REF_DB_TYPE"

    CHANGELOG_FILE=$CURRENT_CHANGELOG
    
    # Build liquibase diff-changelog command based on database type
    # For MariaDB/MySQL, don't include schema/catalog names as they cause issues
    # For other databases, include them for proper schema management
    local liquibase_diff_cmd="liquibase diff-changelog --changelog-file=\"$CHANGELOG_DIR/$CHANGELOG_FILE\""
    
    if [ "$MAIN_DB_TYPE" = "mariadb" ] || [ "$MAIN_DB_TYPE" = "mysql" ]; then
        # For MariaDB/MySQL, don't include schema/catalog to avoid database name prefixes
        liquibase_diff_cmd="$liquibase_diff_cmd --include-schema=false --include-catalog=false"
    else
        # For other databases (PostgreSQL, Oracle, etc.), include schema/catalog
        liquibase_diff_cmd="$liquibase_diff_cmd --include-schema=true --include-tablespace=true --include-catalog=true"
    fi
    
    # Add options to improve diff generation accuracy
    liquibase_diff_cmd="$liquibase_diff_cmd --diff-types=tables,columns,indexes,foreignkeys,primarykeys,uniqueconstraints"
    

    if [ "$CHANGELOG_FORMAT" = "xml" ]; then
        eval $liquibase_diff_cmd
        include_changelog_if_valid "$CHANGELOG_FILE"
        
        ./rollback-xml.sh "$CHANGELOG_DIR/$CHANGELOG_FILE"
    else
        eval $liquibase_diff_cmd
        include_changelog_if_valid "$CHANGELOG_FILE"
        
        if [ -f "$CHANGELOG_DIR/$CHANGELOG_FILE" ]; then
            ./fix-changelog-order.sh "$CHANGELOG_DIR/$CHANGELOG_FILE"
            ./rollback-sql.sh "$CHANGELOG_DIR/$CHANGELOG_FILE"
        else
            echo "⚠️  No changelog file generated - skipping rollback statement addition"
        fi
        
        # Only process initial changelog if it exists and we're not in generate mode
        if [ -f "$CHANGELOG_DIR/$INIT_CHANGELOG" ] && [ "$GENERATE_MODE" != true ]; then
            ./rollback-sql.sh "$CHANGELOG_DIR/$INIT_CHANGELOG"
        fi
    fi

    printf "\n✅ Liquibase migration ready!\n"
}

run_update() {
    create_ref_db "$REF_DB_HOST" "$REF_DB_USER" "$REF_DB_PASSWORD" "$REF_DB_NAME" "$REF_DB_TYPE"
    echo "🚀 Applying database changes..."
    liquibase update
    if [ $? -eq 0 ]; then
        printf "\n✅ Liquibase migration complete!\n"
    else
        printf "\n⚠️ Liquibase update failed — attempting changelogSync instead...\n"
        if liquibase changelogSync; then
            printf "\n✅ changelogSync complete! Schema assumed to be already in place.\n"
        else
            printf "\n❌ changelogSync also failed. Divine intervention may be required.\n"
        fi
    fi
}

run_cleanup() {
    printf "\n🧹 Cleaning up: Dropping temporary database...\n"

	local db_type=$REF_DB_TYPE
    
    case "$db_type" in
        postgresql)
            PGPASSWORD="$REF_DB_PASSWORD" psql -h "$REF_DB_HOST" -U "$REF_DB_USER" -d "postgres" -c "DROP DATABASE IF EXISTS \"$REF_DB_NAME\";"
            ;;
        mysql)
            mysql -h "$REF_DB_HOST" -u "$REF_DB_USER" -p"$REF_DB_PASSWORD" -e "DROP DATABASE IF EXISTS \`$REF_DB_NAME\`;"
            ;;
        mariadb)
            mysql -h "$REF_DB_HOST" -u "$REF_DB_USER" -p"$REF_DB_PASSWORD" -e "DROP DATABASE IF EXISTS \`$REF_DB_NAME\`;"
            ;;
        sqlite)
            rm -f "/data/$REF_DB_NAME.db"
            ;;
    esac
    exit 0
}

run_rollback_operations() {
    printf "\n🔄 Starting rollback operation...\n"
    
    if [ "$ROLLBACK_COUNT" = "all" ]; then
        rollback_all
    elif [ -n "$ROLLBACK_TO_DATE" ]; then
        rollback_to_date "$ROLLBACK_TO_DATE"
    elif [ -n "$ROLLBACK_TO_CHANGESET" ]; then
        rollback_to_changeset "$ROLLBACK_TO_CHANGESET"
    elif [ -n "$ROLLBACK_TO_TAG" ]; then
        rollback_to_tag "$ROLLBACK_TO_TAG"
    elif [ "$ROLLBACK_COUNT" -gt 0 ]; then
        rollback_by_count "$ROLLBACK_COUNT"
    else
        echo "❌ Invalid rollback parameters"
        echo "Use --help for usage information"
        exit 1
    fi
    
    ROLLBACK_EXIT_CODE=$?
    if [ $ROLLBACK_EXIT_CODE -eq 0 ]; then
        printf "\n✅ Rollback operation completed successfully!\n"
    else
        printf "\n❌ Rollback operation failed!\n"
        exit $ROLLBACK_EXIT_CODE
    fi
}

show_help() {
	echo "🚀 Liquibase Migration Script"
	echo ""
	echo "Usage: $0 [OPTIONS]"
	echo ""
	echo "Migration Options:"
	echo "  -g, --generate, generate          Generate new changelog only (don't apply)"
	echo "  -u, --update, update              Apply migrations only (don't generate)"
	echo "  -i, --init, init                  Initialize database with initial changelog"
	echo "  -a, --generate-and-update, generate-and-update  Generate and apply changelog"
	echo "  -c, --clean, clean                Clean up temporary database"
	echo ""
	echo "Rollback Options:"
	echo "  -r, --rollback, rollback COUNT    Rollback COUNT changesets"
	echo "  -rtd, --rollback-to-date, rollback-to-date DATE Rollback to specific date (YYYY-MM-DD)"
	echo "  -rtc, --rollback-to-changeset, rollback-to-changeset ID Rollback to specific changeset ID"
	echo "  -rtt, --rollback-to-tag, rollback-to-tag TAG   Rollback to specific tag"
	echo "  -ra, --rollback-all, rollback-all Rollback all changes"
	echo "  -s, --status, status              Show current database status"
	echo ""
	echo "Direct Liquibase Access:"
	echo "  liquibase [LIQUIBASE_COMMAND]     Run Liquibase commands directly"
	echo ""
	echo "Environment Variables:"
	echo "  MAIN_DB_TYPE           Main database type (postgresql, mysql, oracle, sqlserver, h2)"
	echo "  MAIN_DB_HOST           Main database host"
	echo "  MAIN_DB_PORT           Main database port (default: 5432)"
	echo "  MAIN_DB_USER           Main database user"
	echo "  MAIN_DB_PASSWORD       Main database password"
	echo "  MAIN_DB_NAME           Main database name"
	echo "  REF_DB_TYPE            Reference database type (postgresql, mysql, oracle, sqlserver, h2)"
	echo "  REF_DB_HOST            Reference database host"
	echo "  REF_DB_PORT            Reference database port (default: 5432)"
	echo "  REF_DB_USER            Reference database user"
	echo "  REF_DB_PASSWORD        Reference database password"
	echo "  REF_DB_NAME            Reference database name"
	echo "  CHANGELOG_FORMAT       Changelog format (sql|xml, default: sql)"
	echo "  CHANGELOG_DIR          Changelog directory (default: /liquibase/changelog)"
	echo "  SCHEMA_DIR             Schema directory (default: /liquibase/schema)"
	echo "  SCHEMA_SCRIPTS         Comma-separated list of schema scripts"
	echo "  REFERENCE_SCHEMA       Single schema script override"
	echo ""
	echo "Examples:"
	echo "  $0 generate                        # Generate new changelog (no dashes)"
	echo "  $0 --generate                      # Generate new changelog (with dashes)"
	echo "  $0 update                          # Apply pending migrations"
	echo "  $0 rollback 2                      # Rollback last 2 changesets"
	echo "  $0 rollback-to-date 2024-01-01     # Rollback to specific date"
	echo "  $0 status                          # Show current status"
	echo "  $0 liquibase --help                # Run Liquibase help directly"
	echo "  $0 liquibase status                # Run Liquibase status directly"
}

include_changelog_if_valid() {
	local changelog_path=$1

	# Check if jq is installed
	if ! command -v jq &>/dev/null; then
		echo "❌ jq not found. Please install jq to process JSON."
		exit 1
	fi

	# Check if changelog file exists and is non-empty
	if [ ! -f "$CHANGELOG_DIR/$changelog_path" ] || [ ! -s "$CHANGELOG_DIR/$changelog_path" ]; then
		printf "⚠️ Changelog file is missing or empty: %s\n" "$changelog_path"
		return 0
	fi

	# Check if the master changelog is writable
	if [ ! -w "$MASTER_CHANGELOG" ]; then
		echo "❌ Cannot write to master changelog: Permission denied → $MASTER_CHANGELOG"
		exit 1
	fi

	# Check if the changelog is already included
	if jq -e ".databaseChangeLog[] | select(.include.file == \"$changelog_path\")" "$MASTER_CHANGELOG" >/dev/null; then
		printf "ℹ️ Already included: %s\n" "$changelog_path"
		return 0
	fi

	# Add new include to databaseChangeLog array
	tmp_file=$(mktemp)
	jq ".databaseChangeLog += [{ \"include\": { \"file\": \"$changelog_path\", \"relativeToChangelogFile\": true } }]" \
		"$MASTER_CHANGELOG" >"$tmp_file"

	# Verify the new JSON is valid before overwriting
	if jq -e . "$tmp_file" >/dev/null; then
		cat "$tmp_file" >"$MASTER_CHANGELOG"
		printf "📌 Added include to master changelog: %s\n" "$changelog_path"
	else
		echo "❌ Failed to update master changelog: Invalid JSON generated."
		rm "$tmp_file"
		exit 1
	fi
}

# Parse command line arguments
parse_arguments() {
	while [[ $# -gt 0 ]]; do
		case $1 in
			-g | --generate | generate)
				RUN_GENERATE=true
				RUN_UPDATE=false
				DROP_DB=true
				shift
				;;
			-u | --update | update)
				RUN_GENERATE=false
				DROP_DB=true
				shift
				;;
			-i | --init | init)
				INIT=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				DROP_DB=true
				shift
				;;
			-a | --generate-and-update | generate-and-update)
				RUN_GENERATE=true
				RUN_UPDATE=true
				DROP_DB=true
				shift
				;;
			-c | --clean | clean)
				DROP_DB=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				shift
				;;
			-r | --rollback | rollback)
				ROLLBACK_MODE=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				ROLLBACK_COUNT="$2"
				shift 2
				;;
			-rtd | --rollback-to-date | rollback-to-date)
				ROLLBACK_MODE=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				ROLLBACK_TO_DATE="$2"
				shift 2
				;;
			-rtc | --rollback-to-changeset | rollback-to-changeset)
				ROLLBACK_MODE=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				ROLLBACK_TO_CHANGESET="$2"
				shift 2
				;;
			-rtt | --rollback-to-tag | rollback-to-tag)
				ROLLBACK_MODE=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				ROLLBACK_TO_TAG="$2"
				shift 2
				;;
			-ra | --rollback-all | rollback-all)
				ROLLBACK_MODE=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				ROLLBACK_COUNT="all"
				shift
				;;
			-s | --status | status)
				RUN_GENERATE=false
				RUN_UPDATE=false
				show_rollback_status
				exit 0
				;;
			-h | --help | help)
				show_help
				exit 0
				;;
			liquibase)
				# Pass through to Liquibase directly
				shift
				echo "🚀 Running Liquibase command directly..."
				exec liquibase "$@"
				;;
			bash)
				echo "🐚 Starting bash shell..."
				exec /bin/bash
				;;
			sh)
				echo "🐚 Starting sh shell..."
				exec /bin/sh
				;;
			*)
				exec "$@"
				;;
		esac
	done
}

# Main execution
main() {
	validate_env_vars
	discover_schema_scripts
	parse_arguments "$@"
	
	# Set global Liquibase environment variables
	set_liquibase_env
	
	# Create reference database first
	create_ref_db "$REF_DB_HOST" "$REF_DB_USER" "$REF_DB_PASSWORD" "$REF_DB_NAME" "$REF_DB_TYPE"
	
	# Wait for both databases
	wait_for_db "$MAIN_DB_HOST" "$MAIN_DB_PORT"  "$MAIN_DB_USER" "$MAIN_DB_PASSWORD" "$MAIN_DB_NAME" "$MAIN_DB_TYPE"
	wait_for_db "$REF_DB_HOST" "$MAIN_DB_PORT" "$REF_DB_USER" "$REF_DB_PASSWORD" "$REF_DB_NAME" "$REF_DB_TYPE"

	if [ "$INIT" = true ]; then
		run_init
	fi

	if [ "$RUN_GENERATE" = true ]; then
		run_generate
	fi

	if [ "$RUN_UPDATE" = true ]; then
		run_update
	fi

	if [ "$ROLLBACK_MODE" = true ]; then
		run_rollback_operations
	fi

	if [ "$DROP_DB" = true ]; then
		run_cleanup
	fi
}

# Run main function with all arguments
main "$@"

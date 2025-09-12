#!/bin/bash

set -e

# Configuration
CHANGELOG_DIR=${CHANGELOG_DIR:-/liquibase/changelog}
SCHEMA_DIR=${SCHEMA_DIR:-/liquibase/schema}
MASTER_CHANGELOG=${MASTER_CHANGELOG:-$CHANGELOG_DIR/changelog.json}
INIT_CHANGELOG=${INIT_CHANGELOG:-changelog-initial.sql}
CURRENT_CHANGELOG=changelog-$(date +%Y%m%d-%H%M%S).sql

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
	local required_vars=("MAIN_DB_HOST" "MAIN_DB_USER" "MAIN_DB_NAME" "REF_DB_HOST" "REF_DB_USER" "REF_DB_NAME")
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
	REF_DB_PASSWORD=${REF_DB_PASSWORD:-""}
	CHANGELOG_FORMAT=${CHANGELOG_FORMAT:-sql}
}

# Discover schema scripts
discover_schema_scripts() {
	if [ -n "$SCHEMA_SCRIPTS" ]; then
		# Parse comma-separated list of scripts
		IFS=',' read -ra SCRIPTS <<< "$SCHEMA_SCRIPTS"
	elif [ -n "$REFERENCE_SCHEMA" ]; then
		# Single script override
		SCRIPTS=("$REFERENCE_SCHEMA")
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
	
	echo "🏗️ Creating reference database $db_name..."
	
	# Try to create the database (ignore error if it already exists)
	if PGPASSWORD="$db_password" psql -h "$db_host" -U "$db_user" -d "postgres" -c "CREATE DATABASE \"$db_name\";" &>/dev/null; then
		echo "✅ Reference database $db_name created successfully!"
	elif PGPASSWORD="$db_password" psql -h "$db_host" -U "$db_user" -d "$db_name" -c '\q' &>/dev/null; then
		echo "ℹ️ Reference database $db_name already exists."
	else
		echo "⚠️ Could not create or verify reference database $db_name. Will attempt to continue..."
	fi
}

wait_for_db() {
	local db_host=$1
	local db_user=$2
	local db_password=$3
	local db_name=$4
	
	local RETRIES=20
	local WAIT=30

	echo "⏳ Waiting for $db_name to be ready..."

	for ((i = 1; i <= RETRIES; i++)); do
		if PGPASSWORD="$db_password" psql -h "$db_host" -U "$db_user" -d "$db_name" -c '\q' &>/dev/null; then
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
    
    echo "📝 Running SQL scripts on database: $db_name"

    for script in "${SCRIPTS[@]}"; do
        if [ -f "$script" ]; then
            echo "  - Running $script on $db_name"
            PGPASSWORD="$db_password" psql \
                -h "$db_host" \
                -U "$db_user" \
                -d "$db_name" \
                -f "$script"
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
    
    local table_count=$(PGPASSWORD="$db_password" psql -h "$db_host" -U "$db_user" -d "$db_name" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "0")
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
	
	if liquibase rollbackDate "$target_date"; then
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
	
	if liquibase rollback "$changeset_id"; then
		echo "✅ Rollback to changeset successful!"
		show_rollback_status
		return 0
	else
		echo "❌ Rollback to changeset failed!"
		return 1
	fi
}

rollback_to_tag() {
	local tag=$1
	echo "🔄 Rolling back to tag: $tag"
	
	if liquibase rollbackTag "$tag"; then
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

show_help() {
	echo "🚀 Liquibase Migration Script"
	echo ""
	echo "Usage: $0 [OPTIONS]"
	echo ""
	echo "Migration Options:"
	echo "  -g, --generate          Generate new changelog only (don't apply)"
	echo "  -u, --update            Apply migrations only (don't generate)"
	echo "  --init                  Initialize database with initial changelog"
	echo "  --clean                 Clean up temporary database"
	echo ""
	echo "Rollback Options:"
	echo "  -r, --rollback COUNT    Rollback COUNT changesets"
	echo "  --rollback-to-date DATE Rollback to specific date (YYYY-MM-DD)"
	echo "  --rollback-to-changeset ID Rollback to specific changeset ID"
	echo "  --rollback-to-tag TAG   Rollback to specific tag"
	echo "  --rollback-all          Rollback all changes"
	echo "  --status                Show current database status"
	echo ""
	echo "Environment Variables:"
	echo "  MAIN_DB_HOST           Main database host"
	echo "  MAIN_DB_USER           Main database user"
	echo "  MAIN_DB_PASSWORD       Main database password"
	echo "  MAIN_DB_NAME           Main database name"
	echo "  REF_DB_HOST            Reference database host"
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
	echo "  $0 --generate                    # Generate new changelog"
	echo "  $0 --update                      # Apply pending migrations"
	echo "  $0 --rollback 2                  # Rollback last 2 changesets"
	echo "  $0 --rollback-to-date 2024-01-01 # Rollback to specific date"
	echo "  $0 --status                      # Show current status"
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
			-g | --generate)
				RUN_UPDATE=false
				shift
				;;
			-u | --update)
				RUN_GENERATE=false
				shift
				;;
			-i | --init)
				INIT=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				shift
				;;
			--c | --clean)
				DROP_DB=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				shift
				;;
			-r | --rollback)
				ROLLBACK_MODE=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				ROLLBACK_COUNT="$2"
				shift 2
				;;
			-rtd | --rollback-to-date)
				ROLLBACK_MODE=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				ROLLBACK_TO_DATE="$2"
				shift 2
				;;
			-rtc | --rollback-to-changeset)
				ROLLBACK_MODE=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				ROLLBACK_TO_CHANGESET="$2"
				shift 2
				;;
			-rtt | --rollback-to-tag)
				ROLLBACK_MODE=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				ROLLBACK_TO_TAG="$2"
				shift 2
				;;
			-ra | --rollback-all)
				ROLLBACK_MODE=true
				RUN_GENERATE=false
				RUN_UPDATE=false
				ROLLBACK_COUNT="all"
				shift
				;;
			-s | --status)
				RUN_GENERATE=false
				RUN_UPDATE=false
				show_rollback_status
				exit 0
				;;
			-h | --help)
				show_help
				exit 0
				;;
			*)
				echo "❌ Unknown option: $1"
				echo "Use --help for usage information"
				exit 1
				;;
		esac
	done
}

# Main execution
main() {
	validate_env_vars
	discover_schema_scripts
	parse_arguments "$@"
	
	# Create reference database first
	create_ref_db "$REF_DB_HOST" "$REF_DB_USER" "$REF_DB_PASSWORD" "$REF_DB_NAME"
	
	# Wait for both databases
	wait_for_db "$MAIN_DB_HOST" "$MAIN_DB_USER" "$MAIN_DB_PASSWORD" "$MAIN_DB_NAME"
	wait_for_db "$REF_DB_HOST" "$REF_DB_USER" "$REF_DB_PASSWORD" "$REF_DB_NAME"

	if [ "$INIT" = true ]; then
		echo "🚀 Initializing database changelog..."
		
		# Check if main database is empty
		if is_database_empty "$MAIN_DB_HOST" "$MAIN_DB_USER" "$MAIN_DB_PASSWORD" "$MAIN_DB_NAME"; then
			echo "📋 Main database is empty, generating changelog from reference database..."
			
			# Apply schema to reference database
			run_sql_scripts_on_db "$REF_DB_HOST" "$REF_DB_USER" "$REF_DB_PASSWORD" "$REF_DB_NAME"

			# Generate changelog from reference database
			if [ ! -f "$CHANGELOG_DIR/$INIT_CHANGELOG" ]; then
				echo "📝 Generating initial changelog from reference database..."
				LIQUIBASE_COMMAND_URL="jdbc:postgresql://$REF_DB_HOST:5432/$REF_DB_NAME" \
				liquibase --changelog-file="$CHANGELOG_DIR/$INIT_CHANGELOG" generateChangeLog \
					--includeSchema=true \
					--includeTablespace=true \
					--includeCatalog=true
				
				# Add rollback statements to initial changelog
				if [ -f "$CHANGELOG_DIR/$INIT_CHANGELOG" ]; then
					echo "🔧 Adding rollback statements to initial changelog..."
					python3 rollback-sql.py "$CHANGELOG_DIR/$INIT_CHANGELOG"
				fi
			else
				echo "⚠️ $INIT_CHANGELOG already exists. Skipping generation."
			fi

			# Apply the generated changelog to main database
			echo "📋 Applying initial changelog to main database..."
			LIQUIBASE_COMMAND_URL="jdbc:postgresql://$MAIN_DB_HOST:5432/$MAIN_DB_NAME" \
			liquibase update
			
		else
			echo "📋 Main database has existing schema, generating changelog from current state..."
			
			# Generate changelog directly from main database
			if [ ! -f "$CHANGELOG_DIR/$INIT_CHANGELOG" ]; then
				LIQUIBASE_COMMAND_URL="jdbc:postgresql://$MAIN_DB_HOST:5432/$MAIN_DB_NAME" \
				liquibase --changelog-file="$CHANGELOG_DIR/$INIT_CHANGELOG" generateChangeLog \
					--includeSchema=true \
					--includeTablespace=true \
					--includeCatalog=true
				
				# Add rollback statements to initial changelog
				if [ -f "$CHANGELOG_DIR/$INIT_CHANGELOG" ]; then
					echo "🔧 Adding rollback statements to initial changelog..."
					python3 rollback-sql.py "$CHANGELOG_DIR/$INIT_CHANGELOG"
				fi
			else
				echo "⚠️ $INIT_CHANGELOG already exists. Skipping generation."
			fi
			
			# Mark current state as deployed
			echo "📋 Synchronizing changelog with current state..."
			LIQUIBASE_COMMAND_URL="jdbc:postgresql://$MAIN_DB_HOST:5432/$MAIN_DB_NAME" \
			liquibase changelogSync
		fi

		include_changelog_if_valid "$INIT_CHANGELOG"
		
		echo "✅ Initialization complete! Database schema is now version-controlled."
		DROP_DB=true
		exit 0
	fi

	if [ "$RUN_GENERATE" = true ]; then
		create_ref_db "$REF_DB_HOST" "$REF_DB_USER" "$REF_DB_PASSWORD" "$REF_DB_NAME"
		run_sql_scripts_on_db "$REF_DB_HOST" "$REF_DB_USER" "$REF_DB_PASSWORD" "$REF_DB_NAME"

		echo "🔄 Generating diff changelog..."
		CHANGELOG_FILE=$CURRENT_CHANGELOG
		
		if [ "$CHANGELOG_FORMAT" = "xml" ]; then
			LIQUIBASE_COMMAND_URL="jdbc:postgresql://$MAIN_DB_HOST:5432/$MAIN_DB_NAME" \
			LIQUIBASE_COMMAND_REFERENCE_URL="jdbc:postgresql://$REF_DB_HOST:5432/$REF_DB_NAME" \
			liquibase diff-changelog --changelog-file="$CHANGELOG_DIR/$CHANGELOG_FILE" --format=xml --include-schema=true --include-tablespace=true --include-catalog=true --include-objects="columns, foreignkeys, indexes, primarykeys, tables, uniqueconstraints, views, functions, triggers, sequences"
			include_changelog_if_valid "$CHANGELOG_FILE"
			
			echo "🔧 Adding rollback statements to XML changelog..."
			python3 rollback-xml.py "$CHANGELOG_DIR/$CHANGELOG_FILE"
		else
			LIQUIBASE_COMMAND_URL="jdbc:postgresql://$MAIN_DB_HOST:5432/$MAIN_DB_NAME" \
			LIQUIBASE_COMMAND_REFERENCE_URL="jdbc:postgresql://$REF_DB_HOST:5432/$REF_DB_NAME" \
			liquibase diff-changelog --changelog-file="$CHANGELOG_DIR/$CHANGELOG_FILE" --include-schema=true --include-tablespace=true --include-catalog=true --include-objects="columns, foreignkeys, indexes, primarykeys, tables, uniqueconstraints, views, functions, triggers, sequences"
			include_changelog_if_valid "$CHANGELOG_FILE"
			
			if [ -f "$CHANGELOG_DIR/$CHANGELOG_FILE" ]; then
				echo "🔧 Adding comprehensive rollback statements to SQL changelog..."
				python3 rollback-sql.py "$CHANGELOG_DIR/$CHANGELOG_FILE"
			else
				echo "⚠️  No changelog file generated - skipping rollback statement addition"
			fi
			
			if [ -f "$CHANGELOG_DIR/$INIT_CHANGELOG" ]; then
				echo "🔧 Adding rollback statements to existing initial changelog..."
				python3 rollback-sql.py "$CHANGELOG_DIR/$INIT_CHANGELOG"
			fi
		fi

		printf "\n✅ Liquibase migration ready!\n"
	fi

	if [ "$RUN_UPDATE" = true ]; then
		echo "🚀 Applying database changes..."
		LIQUIBASE_COMMAND_URL="jdbc:postgresql://$MAIN_DB_HOST:5432/$MAIN_DB_NAME" \
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
		DROP_DB=true

	fi

	# Handle rollback operations
	if [ "$ROLLBACK_MODE" = true ]; then
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
	fi

	if [ "$DROP_DB" = true ]; then
		printf "\n🧹 Cleaning up: Dropping temporary database...\n"
		PGPASSWORD="$REF_DB_PASSWORD" psql -h "$REF_DB_HOST" -U "$REF_DB_USER" -c "DROP DATABASE IF EXISTS $REF_DB_NAME;"
	fi
}

# Run main function with all arguments
main "$@"

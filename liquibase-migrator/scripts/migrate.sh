#!/bin/bash

set -e

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
ROLLBACK_MODE=false
MASTER_CHANGELOG=/liquibase/changelog/changelog.json
INIT_CHANGELOG=changelog-initial.sql
CURRENT_CHANGELOG=changelog-$(date +%Y%m%d-%H%M%S).sql
SCRIPTS=(/liquibase/schema/init-db.sql /liquibase/schema/triggers.sql /liquibase/schema/init-data.sql /liquibase/schema/"${ENV}"-dump.sql)

wait_for_db() {
	local RETRIES=20
	local WAIT=30

	echo "⏳ Waiting for $LIQ_DB_HOST to be ready..."

	for ((i = 1; i <= RETRIES; i++)); do
		if PGPASSWORD="$LIQ_DB_PASSWORD" psql -h "$LIQ_DB_HOST" -U "$LIQ_DB_USER" -d postgres -c '\q' &>/dev/null; then
			echo "✅ Database is ready!"
			return 0
		fi
		echo "  Attempt $i/$RETRIES: DB not ready yet, retrying in $WAITs..."
		sleep $WAIT
	done

	echo "❌ Database connection timed out after $((RETRIES * WAIT)) seconds."
	exit 1
}

run_init_sql_scripts() {
	echo "📝 Running init SQL scripts on main database..."

	local scripts=(
		/liquibase/schema/init-db.sql
		/liquibase/schema/triggers.sql
		/liquibase/schema/init-data.sql
	)

	for script in "${scripts[@]}"; do
		if [ -f "$script" ]; then
			echo "  - Running $script"
			PGPASSWORD="$LIQ_DB_PASSWORD" psql -h "$LIQ_DB_HOST" -U "$LIQ_DB_USER" -d "$LIQ_DB_NAME" -f "$script"
		else
			echo "  ⚠️  Skipping missing script: $script"
		fi
	done
}

show_rollback_status() {
	echo "📊 Current database status:"
	liquibase status
	echo ""
}

rollback_by_count() {
	local count=$1
	echo "🔄 Rolling back $count changeset(s)..."
	
	if liquibase rollback-count "$count"; then
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
	
	if liquibase rollback "$changeset_id"; then
		echo "✅ Rollback to changeset successful!"
		show_rollback_status
		return 0
	else
		echo "❌ Rollback to changeset failed!"
		return 1
	fi
}

rollback_all() {
	echo "🔄 Rolling back all changes..."
	
	if liquibase rollback-count 999999; then
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
	echo "  --rollback-all          Rollback all changes"
	echo "  --status                Show current database status"
	echo ""
	echo "Environment Variables:"
	echo "  LIQ_DB_HOST            Database host"
	echo "  LIQ_DB_USER            Database user"
	echo "  LIQ_DB_PASSWORD        Database password"
	echo "  LIQ_DB_NAME            Database name"
	echo "  LIQ_DB_SNAPSHOT        Temporary database name"
	echo "  CHANGELOG_FORMAT       Changelog format (sql|xml, default: sql)"
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
	if [ ! -f "changelog/$changelog_path" ] || [ ! -s "changelog/$changelog_path" ]; then
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
		--init)
			INIT=true
			RUN_GENERATE=false
			RUN_UPDATE=false
			shift
			;;
		--clean)
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
		--rollback-to-date)
			ROLLBACK_MODE=true
			RUN_GENERATE=false
			RUN_UPDATE=false
			ROLLBACK_TO_DATE="$2"
			shift 2
			;;
		--rollback-to-changeset)
			ROLLBACK_MODE=true
			RUN_GENERATE=false
			RUN_UPDATE=false
			ROLLBACK_TO_CHANGESET="$2"
			shift 2
			;;
		--rollback-all)
			ROLLBACK_MODE=true
			RUN_GENERATE=false
			RUN_UPDATE=false
			ROLLBACK_COUNT="all"
			shift
			;;
		--status)
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

wait_for_db

if [ "$INIT" = true ]; then
	if [ ! -f "changelog/$INIT_CHANGELOG" ]; then
		liquibase --changelog-file="changelog/$INIT_CHANGELOG" generateChangeLog --includeSchema=true --includeTablespace=true --includeCatalog=true
	else
		echo "⚠️ $INIT_CHANGELOG already exists. Skipping generation."
	fi

	include_changelog_if_valid "$INIT_CHANGELOG"
	liquibase changelogSync

	run_init_sql_scripts
fi

if [ "$RUN_GENERATE" = true ]; then
	printf "🛠️ Creating temporary Postgres database: $LIQ_DB_SNAPSHOT..."
	PGPASSWORD="$LIQ_DB_PASSWORD" psql -h "$LIQ_DB_HOST" -U "$LIQ_DB_USER" -d postgres -c "CREATE DATABASE $LIQ_DB_SNAPSHOT;"

	printf "\n📝 Applying reference SQL script to temp db...\n"
	for script in "${SCRIPTS[@]}"; do
		if [ -f "$script" ]; then
			printf "  - Applying %s\n" "$script"
			PGPASSWORD="$LIQ_DB_PASSWORD" psql -h "$LIQ_DB_HOST" -U "$LIQ_DB_USER" -d "$LIQ_DB_SNAPSHOT" -f "$script"
		else
			printf "  ⚠️  Skipping missing script: %s\n" "$script"
		fi
	done


	printf "\n🔄 Generating new changelog...\n"
	CHANGELOG_FILE=$CURRENT_CHANGELOG
	CHANGELOG_FORMAT=${CHANGELOG_FORMAT:-sql}  # Default to SQL, can be overridden with CHANGELOG_FORMAT=xml
	
	if [ "$CHANGELOG_FORMAT" = "xml" ]; then
		liquibase diff-changelog --changelog-file="changelog/$CHANGELOG_FILE" --format=xml --include-schema=true --include-tablespace=true --include-catalog=true --include-objects="columns, foreignkeys, indexes, primarykeys, tables, uniqueconstraints, views, functions, triggers, sequences"
		include_changelog_if_valid "$CHANGELOG_FILE"
		
		# Add rollback statements to the generated XML changelog
		printf "\n🔧 Adding rollback statements to XML changelog...\n"
		python3 rollback-xml.py "changelog/$CHANGELOG_FILE"
	else
		liquibase diff-changelog --changelog-file="changelog/$CHANGELOG_FILE" --include-schema=true --include-tablespace=true --include-catalog=true --include-objects="columns, foreignkeys, indexes, primarykeys, tables, uniqueconstraints, views, functions, triggers, sequences"
		include_changelog_if_valid "$CHANGELOG_FILE"
		
		# Add rollback statements to the generated SQL changelog
		if [ -f "changelog/$CHANGELOG_FILE" ]; then
			printf "\n🔧 Adding comprehensive rollback statements to SQL changelog...\n"
			python3 rollback-sql.py "changelog/$CHANGELOG_FILE"
		else
			printf "\n⚠️  No changelog file generated - skipping rollback statement addition\n"
		fi
	fi

	DROP_DB=true

	printf "\n✅ Liquibase migration ready!\n"
fi

if [ "$RUN_UPDATE" = true ]; then
	run_init_sql_scripts
	printf "\n🚀 Applying database changes...\n"
	if liquibase update; then
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
	PGPASSWORD="$LIQ_DB_PASSWORD" psql -h "$LIQ_DB_HOST" -U "$LIQ_DB_USER" -c "DROP DATABASE IF EXISTS $LIQ_DB_SNAPSHOT;"
fi

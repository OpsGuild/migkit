#!/bin/bash

set -e

# Configuration
SCRIPT_NAME="rollback-sql.sh"

# Function to show usage
show_usage() {
    echo "❌ Error: Please provide a changelog file path"
    echo "Usage: $SCRIPT_NAME <changelog-file>"
    exit 1
}

# Function to extract table name from SQL using sed
extract_table_name() {
    local sql="$1"
    local sql_upper=$(echo "$sql" | tr '[:lower:]' '[:upper:]' | tr -s ' ')
    
    # CREATE TABLE
    if echo "$sql_upper" | grep -q "^CREATE TABLE"; then
        echo "$sql" | sed -n 's/.*CREATE[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:](]*\)"*.*/\2/p' | head -1
    # ALTER TABLE
    elif echo "$sql_upper" | grep -q "^ALTER TABLE"; then
        echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1
    # DROP TABLE
    elif echo "$sql_upper" | grep -q "^DROP TABLE"; then
        echo "$sql" | sed -n 's/.*DROP[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1
    # TRUNCATE TABLE
    elif echo "$sql_upper" | grep -q "^TRUNCATE TABLE"; then
        echo "$sql" | sed -n 's/.*TRUNCATE[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1
    # INSERT INTO
    elif echo "$sql_upper" | grep -q "^INSERT INTO"; then
        echo "$sql" | sed -n 's/.*INSERT[[:space:]]\+INTO[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1
    # UPDATE
    elif echo "$sql_upper" | grep -q "^UPDATE"; then
        echo "$sql" | sed -n 's/.*UPDATE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1
    # DELETE FROM
    elif echo "$sql_upper" | grep -q "^DELETE FROM"; then
        echo "$sql" | sed -n 's/.*DELETE[[:space:]]\+FROM[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1
    fi
}

# Function to extract column info from ALTER TABLE statements
extract_column_info() {
    local sql="$1"
    local sql_upper=$(echo "$sql" | tr '[:lower:]' '[:upper:]' | tr -s ' ')
    
    # ADD COLUMN
    if echo "$sql_upper" | grep -q "ADD.*COLUMN"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local column=$(echo "$sql" | sed -n 's/.*ADD[[:space:]]\+COLUMN[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        echo "${table}|${column}"
    # DROP COLUMN
    elif echo "$sql_upper" | grep -q "DROP COLUMN"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local column=$(echo "$sql" | sed -n 's/.*DROP[[:space:]]\+COLUMN[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        echo "${table}|${column}"
    # ALTER COLUMN
    elif echo "$sql_upper" | grep -q "ALTER COLUMN"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local column=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+COLUMN[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        echo "${table}|${column}"
    # RENAME COLUMN
    elif echo "$sql_upper" | grep -q "RENAME COLUMN"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local column=$(echo "$sql" | sed -n 's/.*RENAME[[:space:]]\+COLUMN[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        echo "${table}|${column}"
    fi
}

# Function to extract constraint info from ALTER TABLE statements
extract_constraint_info() {
    local sql="$1"
    local sql_upper=$(echo "$sql" | tr '[:lower:]' '[:upper:]' | tr -s ' ')
    
    # ADD CONSTRAINT
    if echo "$sql_upper" | grep -q "ADD CONSTRAINT"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local constraint=$(echo "$sql" | sed -n 's/.*ADD[[:space:]]\+CONSTRAINT[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        echo "${table}|${constraint}"
    # DROP CONSTRAINT
    elif echo "$sql_upper" | grep -q "DROP CONSTRAINT"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local constraint=$(echo "$sql" | sed -n 's/.*DROP[[:space:]]\+CONSTRAINT[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        echo "${table}|${constraint}"
    # ADD PRIMARY KEY
    elif echo "$sql_upper" | grep -q "ADD PRIMARY KEY"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        echo "${table}|PRIMARY_KEY"
    # DROP PRIMARY KEY
    elif echo "$sql_upper" | grep -q "DROP PRIMARY KEY"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        echo "${table}|PRIMARY_KEY"
    fi
}

# Function to extract index info
extract_index_info() {
    local sql="$1"
    local sql_upper=$(echo "$sql" | tr '[:lower:]' '[:upper:]' | tr -s ' ')
    
    # CREATE INDEX
    if echo "$sql_upper" | grep -q "CREATE.*INDEX"; then
        local index=$(echo "$sql" | sed -n 's/.*CREATE[[:space:]]\+.*INDEX[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        local table=$(echo "$sql" | sed -n 's/.*ON[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        echo "${index}|${table}"
    # DROP INDEX
    elif echo "$sql_upper" | grep -q "DROP INDEX"; then
        local index=$(echo "$sql" | sed -n 's/.*DROP[[:space:]]\+INDEX[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        echo "${index}|"
    fi
}

# Function to generate rollback SQL
generate_rollback() {
    local sql="$1"
    local sql_upper=$(echo "$sql" | tr '[:lower:]' '[:upper:]' | tr -s ' ')
    
    if echo "$sql_upper" | grep -q "^CREATE[[:space:]]\+TABLE"; then
        local table_name=$(extract_table_name "$sql")
        if [[ -n "$table_name" ]]; then
            # Clean up table name format - just quote if not already quoted
            if [[ ! "$table_name" =~ \".*\" ]]; then
                table_name="\"$table_name\""
            fi
            echo "DROP TABLE IF EXISTS $table_name;"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "^DROP[[:space:]]\+TABLE"; then
        local table_name=$(extract_table_name "$sql")
        if [[ -n "$table_name" ]]; then
            echo "-- Rollback for DROP TABLE $table_name requires original table definition"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "ALTER[[:space:]]\+TABLE.*ADD.*COLUMN"; then
        local column_info=$(extract_column_info "$sql")
        local table_name=$(echo "$column_info" | cut -d'|' -f1)
        local column_name=$(echo "$column_info" | cut -d'|' -f2)
        if [[ -n "$table_name" && -n "$column_name" ]]; then
            # Clean up names - just quote if not already quoted
            if [[ ! "$table_name" =~ \".*\" ]]; then
                table_name="\"$table_name\""
            fi
            if [[ ! "$column_name" =~ \".*\" ]]; then
                column_name="\"$column_name\""
            fi
            echo "ALTER TABLE $table_name DROP COLUMN IF EXISTS $column_name;"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "ALTER[[:space:]]\+TABLE.*ADD.*UNIQUE"; then
        local table_name=$(extract_table_name "$sql")
        local constraint_name=$(echo "$sql" | sed -n 's/.*ADD[[:space:]]\+CONSTRAINT[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        if [[ -z "$constraint_name" ]]; then
            # If no explicit constraint name, generate one based on table and column
            local column=$(echo "$sql" | sed -n 's/.*UNIQUE[[:space:]]*([[:space:]]*"*\([^"[:space:]]*\)"*[[:space:]]*).*/\1/p' | head -1)
            constraint_name="${table_name}_${column}_key"
        fi
        if [[ -n "$table_name" && -n "$constraint_name" ]]; then
            # Clean up names - just quote if not already quoted
            if [[ ! "$table_name" =~ \".*\" ]]; then
                table_name="\"$table_name\""
            fi
            if [[ ! "$constraint_name" =~ \".*\" ]]; then
                constraint_name="\"$constraint_name\""
            fi
            echo "ALTER TABLE $table_name DROP CONSTRAINT IF EXISTS $constraint_name;"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "ALTER[[:space:]]\+TABLE.*DROP.*COLUMN"; then
        local column_info=$(extract_column_info "$sql")
        local table_name=$(echo "$column_info" | cut -d'|' -f1)
        local column_name=$(echo "$column_info" | cut -d'|' -f2)
        if [[ -n "$table_name" && -n "$column_name" ]]; then
            echo "-- Rollback for DROP COLUMN $column_name requires original column definition"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "ALTER[[:space:]]\+TABLE.*ADD.*CONSTRAINT"; then
        local constraint_info=$(extract_constraint_info "$sql")
        local table_name=$(echo "$constraint_info" | cut -d'|' -f1)
        local constraint_name=$(echo "$constraint_info" | cut -d'|' -f2)
        if [[ -n "$table_name" && -n "$constraint_name" ]]; then
            # Clean up names - just quote if not already quoted
            if [[ ! "$table_name" =~ \".*\" ]]; then
                table_name="\"$table_name\""
            fi
            if [[ ! "$constraint_name" =~ \".*\" ]]; then
                constraint_name="\"$constraint_name\""
            fi
            echo "ALTER TABLE $table_name DROP CONSTRAINT IF EXISTS $constraint_name;"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "ALTER[[:space:]]\+TABLE.*ADD.*UNIQUE"; then
        local table_name=$(extract_table_name "$sql")
        local constraint_name=$(echo "$sql" | sed -n 's/.*ADD[[:space:]]\+CONSTRAINT[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        if [[ -z "$constraint_name" ]]; then
            # If no explicit constraint name, generate one based on table and column
            local column=$(echo "$sql" | sed -n 's/.*UNIQUE[[:space:]]*([[:space:]]*"*\([^"[:space:]]*\)"*[[:space:]]*).*/\1/p' | head -1)
            constraint_name="${table_name}_${column}_key"
        fi
        if [[ -n "$table_name" && -n "$constraint_name" ]]; then
            # Clean up names - just quote if not already quoted
            if [[ ! "$table_name" =~ \".*\" ]]; then
                table_name="\"$table_name\""
            fi
            if [[ ! "$constraint_name" =~ \".*\" ]]; then
                constraint_name="\"$constraint_name\""
            fi
            echo "ALTER TABLE $table_name DROP CONSTRAINT IF EXISTS $constraint_name;"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "ALTER[[:space:]]\+TABLE.*DROP.*CONSTRAINT"; then
        local constraint_info=$(extract_constraint_info "$sql")
        local table_name=$(echo "$constraint_info" | cut -d'|' -f1)
        local constraint_name=$(echo "$constraint_info" | cut -d'|' -f2)
        if [[ -n "$table_name" && -n "$constraint_name" ]]; then
            echo "-- Rollback for DROP CONSTRAINT $constraint_name requires original constraint definition"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "ALTER[[:space:]]\+TABLE.*ADD.*PRIMARY.*KEY"; then
        local table_name=$(extract_table_name "$sql")
        if [[ -n "$table_name" ]]; then
            # Clean up table name - just quote if not already quoted
            if [[ ! "$table_name" =~ \".*\" ]]; then
                table_name="\"$table_name\""
            fi
            local pkey_name=$(echo "$table_name" | sed 's/\./_/g' | sed 's/"//g')
            echo "ALTER TABLE $table_name DROP CONSTRAINT IF EXISTS ${pkey_name}_pkey;"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "ALTER[[:space:]]\+TABLE.*DROP.*PRIMARY.*KEY"; then
        local table_name=$(extract_table_name "$sql")
        if [[ -n "$table_name" ]]; then
            echo "-- Rollback for DROP PRIMARY KEY requires original primary key definition"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "ALTER[[:space:]]\+COLUMN.*SET[[:space:]]\+DEFAULT"; then
        local column_info=$(extract_column_info "$sql")
        local table_name=$(echo "$column_info" | cut -d'|' -f1)
        local column_name=$(echo "$column_info" | cut -d'|' -f2)
        if [[ -n "$table_name" && -n "$column_name" ]]; then
            # Clean up names - just quote if not already quoted
            if [[ ! "$table_name" =~ \".*\" ]]; then
                table_name="\"$table_name\""
            fi
            if [[ ! "$column_name" =~ \".*\" ]]; then
                column_name="\"$column_name\""
            fi
            echo "ALTER TABLE $table_name ALTER COLUMN $column_name DROP DEFAULT;"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "ALTER[[:space:]]\+COLUMN.*DROP[[:space:]]\+DEFAULT"; then
        local column_info=$(extract_column_info "$sql")
        local table_name=$(echo "$column_info" | cut -d'|' -f1)
        local column_name=$(echo "$column_info" | cut -d'|' -f2)
        if [[ -n "$table_name" && -n "$column_name" ]]; then
            echo "-- Rollback for DROP DEFAULT requires original default value"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "CREATE.*INDEX"; then
        local index_info=$(extract_index_info "$sql")
        local index_name=$(echo "$index_info" | cut -d'|' -f1)
        if [[ -n "$index_name" ]]; then
            index_name="\"$index_name\""
            echo "DROP INDEX IF EXISTS $index_name;"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "DROP.*INDEX"; then
        local index_info=$(extract_index_info "$sql")
        local index_name=$(echo "$index_info" | cut -d'|' -f1)
        if [[ -n "$index_name" ]]; then
            echo "-- Rollback for DROP INDEX requires original index definition"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "^INSERT"; then
        local table_name=$(extract_table_name "$sql")
        if [[ -n "$table_name" ]]; then
            echo "-- Rollback for INSERT requires identifying the inserted record(s)"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "^UPDATE"; then
        local table_name=$(extract_table_name "$sql")
        if [[ -n "$table_name" ]]; then
            echo "-- Rollback for UPDATE requires original values"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "^DELETE"; then
        local table_name=$(extract_table_name "$sql")
        if [[ -n "$table_name" ]]; then
            echo "-- Rollback for DELETE requires original values"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    elif echo "$sql_upper" | grep -q "^TRUNCATE"; then
        local table_name=$(extract_table_name "$sql")
        if [[ -n "$table_name" ]]; then
            echo "-- Rollback for TRUNCATE requires original data"
        else
            echo "-- Empty rollback (manual intervention required)"
        fi
    else
        echo "-- Empty rollback (manual intervention required)"
    fi
}

# Function to check if a line ends a SQL statement
is_sql_statement_end() {
    local line="$1"
    # Check if line ends with semicolon or is a single-line statement
    if echo "$line" | grep -q ";$" || echo "$line" | grep -q "^[[:space:]]*[A-Z]"; then
        return 0
    fi
    return 1
}

# Function to process changelog file
process_changelog() {
    local filename="$1"
    local temp_file=$(mktemp)
    local added_rollbacks=0
    local skipped_rollbacks=0
    local total_changesets=0
    local in_changeset=false
    local sql_lines=()
    local has_rollback=false
    local changeset_id=""
    
    # Read the file line by line
    while IFS= read -r line; do
        # Check if this is a changeset start
        if echo "$line" | grep -q "^[[:space:]]*--[[:space:]]*changeset"; then
            # Process previous changeset if we have one
            if [[ "$in_changeset" = true ]]; then
                # Add rollback if we have SQL and no existing rollback
                if [[ ${#sql_lines[@]} -gt 0 && "$has_rollback" = false ]]; then
                    local sql=$(printf '%s ' "${sql_lines[@]}" | tr -s ' ')
                    local rollback_sql=$(generate_rollback "$sql")
                    echo "-- rollback $rollback_sql" >> "$temp_file"
                    added_rollbacks=$((added_rollbacks + 1))
                elif [[ "$has_rollback" = true ]]; then
                    skipped_rollbacks=$((skipped_rollbacks + 1))
                fi
                # Add single blank line between changesets
                echo "" >> "$temp_file"
            fi
            
            # Start new changeset
            in_changeset=true
            sql_lines=()
            has_rollback=false
            changeset_id=$(echo "$line" | sed -n 's/.*id:\([^[:space:]]*\).*/\1/p')
            total_changesets=$((total_changesets + 1))
            echo "$line" >> "$temp_file"
        else
            if [[ "$in_changeset" = true ]]; then
                # Check for existing rollback
                if echo "$line" | grep -q "^[[:space:]]*--[[:space:]]*rollback"; then
                    has_rollback=true
                    echo "$line" >> "$temp_file"
                # Check if this is a non-comment SQL line
                elif ! echo "$line" | grep -q "^[[:space:]]*--" && [[ -n "${line// }" ]]; then
                    sql_lines+=("$line")
                    echo "$line" >> "$temp_file"
                    
                    # Check if this line ends the SQL statement
                    if is_sql_statement_end "$line"; then
                        # Add rollback immediately after the SQL statement
                        if [[ "$has_rollback" = false ]]; then
                            local sql=$(printf '%s ' "${sql_lines[@]}" | tr -s ' ')
                            local rollback_sql=$(generate_rollback "$sql")
                            echo "-- rollback $rollback_sql" >> "$temp_file"
                            added_rollbacks=$((added_rollbacks + 1))
                            has_rollback=true
                        fi
                    fi
                # Skip blank lines within changesets (they'll be added between changesets)
                elif [[ -z "${line// }" ]]; then
                    # Skip blank lines - we'll add them between changesets
                    :
                else
                    echo "$line" >> "$temp_file"
                fi
            else
                # Not in a changeset, just write the line
                echo "$line" >> "$temp_file"
            fi
        fi
    done < "$filename"
    
    # Process the last changeset if we have one
    if [[ "$in_changeset" = true ]]; then
        # Add rollback if we have SQL and no existing rollback
        if [[ ${#sql_lines[@]} -gt 0 && "$has_rollback" = false ]]; then
            local sql=$(printf '%s ' "${sql_lines[@]}" | tr -s ' ')
            local rollback_sql=$(generate_rollback "$sql")
            echo "-- rollback $rollback_sql" >> "$temp_file"
            added_rollbacks=$((added_rollbacks + 1))
        elif [[ "$has_rollback" = true ]]; then
            skipped_rollbacks=$((skipped_rollbacks + 1))
        fi
    fi
    
    # Replace original file with processed content
    mv "$temp_file" "$filename"
    
    echo "✅ Added rollbacks to $added_rollbacks changesets"
}

# Main execution
main() {
    if [[ $# -ne 1 ]]; then
        show_usage
    fi
    
    local changelog_file="$1"
    
    if [[ ! -f "$changelog_file" ]]; then
        echo "❌ Error: Changelog file '$changelog_file' not found"
        exit 1
    fi
    
    # Check if file already has rollback statements
    if grep -q "^[[:space:]]*--[[:space:]]*rollback" "$changelog_file"; then
        echo "ℹ️  File already contains rollback statements, skipping: $changelog_file"
        exit 0
    fi
    
    echo "🔧 Adding rollback statements to SQL changelog $changelog_file..."
    process_changelog "$changelog_file"
    echo "⚠️  Note: Please review generated rollback statements for accuracy"
    echo "⚠️  Some complex changes may require manual rollback statements"
}

# Run main function with all arguments
main "$@"

#!/bin/bash

# Script to deduplicate constraints in changelog files
# Analyzes existing changelogs to detect if constraints have already been created
# and removes duplicate constraint changesets from new changelogs

set -e

# Configuration
SCRIPT_NAME="deduplicate-constraints.sh"

# Function to show usage
show_usage() {
    echo "❌ Error: Please provide a changelog file path"
    echo "Usage: $SCRIPT_NAME <changelog-file> [changelog-directory]"
    echo ""
    echo "Arguments:"
    echo "  changelog-file     Path to the changelog file to process"
    echo "  changelog-directory Optional: Directory containing existing changelogs (default: ./changelog)"
    echo ""
    echo "This script will:"
    echo "  1. Scan existing changelogs for constraint definitions"
    echo "  2. Remove duplicate constraint changesets from the target changelog"
    echo "  3. Preserve the original file with a .backup extension"
    exit 1
}

# Function to extract constraint information from SQL
extract_constraint_info() {
    local sql="$1"
    local sql_upper=$(echo "$sql" | tr '[:lower:]' '[:upper:]' | tr -s ' ')
    
    # Extract foreign key constraints - ADD
    if echo "$sql_upper" | grep -q "ADD CONSTRAINT.*FOREIGN KEY"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local constraint=$(echo "$sql" | sed -n 's/.*ADD[[:space:]]\+CONSTRAINT[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        local column=$(echo "$sql" | sed -n 's/.*FOREIGN[[:space:]]\+KEY[[:space:]]*([[:space:]]*"*\([^"[:space:]]*\)"*[[:space:]]*).*/\1/p' | head -1)
        local ref_table=$(echo "$sql" | sed -n 's/.*REFERENCES[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local ref_column=$(echo "$sql" | sed -n 's/.*REFERENCES[[:space:]]\+[^[:space:]]*[[:space:]]*([[:space:]]*"*\([^"[:space:]]*\)"*[[:space:]]*).*/\1/p' | head -1)
        
        if [[ -n "$table" && -n "$constraint" && -n "$column" && -n "$ref_table" && -n "$ref_column" ]]; then
            echo "ADD|FK|${table}|${constraint}|${column}|${ref_table}|${ref_column}"
        fi
    # Extract foreign key constraints - DROP
    elif echo "$sql_upper" | grep -q "DROP CONSTRAINT.*FOREIGN KEY\|DROP CONSTRAINT.*fkey"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local constraint=$(echo "$sql" | sed -n 's/.*DROP[[:space:]]\+CONSTRAINT[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        
        if [[ -n "$table" && -n "$constraint" ]]; then
            echo "DROP|FK|${table}|${constraint}"
        fi
    # Extract unique constraints - ADD
    elif echo "$sql_upper" | grep -q "ADD CONSTRAINT.*UNIQUE"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local constraint=$(echo "$sql" | sed -n 's/.*ADD[[:space:]]\+CONSTRAINT[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        local column=$(echo "$sql" | sed -n 's/.*UNIQUE[[:space:]]*([[:space:]]*"*\([^"[:space:]]*\)"*[[:space:]]*).*/\1/p' | head -1)
        
        if [[ -n "$table" && -n "$constraint" && -n "$column" ]]; then
            echo "ADD|UQ|${table}|${constraint}|${column}"
        fi
    # Extract unique constraints - DROP
    elif echo "$sql_upper" | grep -q "DROP CONSTRAINT.*UNIQUE\|DROP CONSTRAINT.*key"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local constraint=$(echo "$sql" | sed -n 's/.*DROP[[:space:]]\+CONSTRAINT[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        
        if [[ -n "$table" && -n "$constraint" ]]; then
            echo "DROP|UQ|${table}|${constraint}"
        fi
    # Extract check constraints - ADD
    elif echo "$sql_upper" | grep -q "ADD CONSTRAINT.*CHECK"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local constraint=$(echo "$sql" | sed -n 's/.*ADD[[:space:]]\+CONSTRAINT[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        local check_condition=$(echo "$sql" | sed -n 's/.*CHECK[[:space:]]*([[:space:]]*\(.*\)[[:space:]]*).*/\1/p' | head -1)
        
        if [[ -n "$table" && -n "$constraint" && -n "$check_condition" ]]; then
            echo "ADD|CK|${table}|${constraint}|${check_condition}"
        fi
    # Extract check constraints - DROP
    elif echo "$sql_upper" | grep -q "DROP CONSTRAINT.*CHECK"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local constraint=$(echo "$sql" | sed -n 's/.*DROP[[:space:]]\+CONSTRAINT[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        
        if [[ -n "$table" && -n "$constraint" ]]; then
            echo "DROP|CK|${table}|${constraint}"
        fi
    # Extract primary key constraints - ADD
    elif echo "$sql_upper" | grep -q "ADD CONSTRAINT.*PRIMARY KEY"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local constraint=$(echo "$sql" | sed -n 's/.*ADD[[:space:]]\+CONSTRAINT[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        local column=$(echo "$sql" | sed -n 's/.*PRIMARY[[:space:]]\+KEY[[:space:]]*([[:space:]]*"*\([^"[:space:]]*\)"*[[:space:]]*).*/\1/p' | head -1)
        
        if [[ -n "$table" && -n "$constraint" && -n "$column" ]]; then
            echo "ADD|PK|${table}|${constraint}|${column}"
        fi
    # Extract primary key constraints - DROP
    elif echo "$sql_upper" | grep -q "DROP CONSTRAINT.*PRIMARY KEY\|DROP CONSTRAINT.*pkey"; then
        local table=$(echo "$sql" | sed -n 's/.*ALTER[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        local constraint=$(echo "$sql" | sed -n 's/.*DROP[[:space:]]\+CONSTRAINT[[:space:]]\+"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
        
        if [[ -n "$table" && -n "$constraint" ]]; then
            echo "DROP|PK|${table}|${constraint}"
        fi
    fi
}

# Function to extract constraints from inline table definitions
extract_inline_constraints() {
    local sql="$1"
    local sql_upper=$(echo "$sql" | tr '[:lower:]' '[:upper:]' | tr -s ' ')
    
    if echo "$sql_upper" | grep -q "^CREATE TABLE"; then
        local table=$(echo "$sql" | sed -n 's/.*CREATE[[:space:]]\+TABLE[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
        
        # Extract foreign key constraints from inline definitions
        echo "$sql" | grep -i "references" | while read -r line; do
            local column=$(echo "$line" | sed -n 's/.*"*\([^"[:space:]]*\)"*[[:space:]]\+[^[:space:]]*[[:space:]]\+REFERENCES[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\1/p' | head -1)
            local ref_table=$(echo "$line" | sed -n 's/.*REFERENCES[[:space:]]\+"*\([^"[:space:]]*\)"*\.*"*\([^"[:space:]]*\)"*.*/\2/p' | head -1)
            local ref_column=$(echo "$line" | sed -n 's/.*REFERENCES[[:space:]]\+[^[:space:]]*[[:space:]]*([[:space:]]*"*\([^"[:space:]]*\)"*[[:space:]]*).*/\1/p' | head -1)
            
            if [[ -n "$table" && -n "$column" && -n "$ref_table" && -n "$ref_column" ]]; then
                # Generate constraint name based on table and column
                local constraint="${table}_${column}_fkey"
                echo "ADD|FK|${table}|${constraint}|${column}|${ref_table}|${ref_column}"
            fi
        done
        
        # Extract unique constraints from inline definitions
        echo "$sql" | grep -i "unique" | while read -r line; do
            local column=$(echo "$line" | sed -n 's/.*"*\([^"[:space:]]*\)"*[[:space:]]\+[^[:space:]]*[[:space:]]\+UNIQUE.*/\1/p' | head -1)
            if [[ -n "$table" && -n "$column" ]]; then
                local constraint="${table}_${column}_key"
                echo "ADD|UQ|${table}|${constraint}|${column}"
            fi
        done
        
        # Extract primary key constraints from inline definitions
        echo "$sql" | grep -i "primary key" | while read -r line; do
            # Check for explicit constraint name: CONSTRAINT "constraint_name" PRIMARY KEY (column)
            local constraint=$(echo "$line" | sed -n 's/.*CONSTRAINT[[:space:]]\+"\([^"]*\)"[[:space:]]\+PRIMARY[[:space:]]\+KEY.*/\1/p' | head -1)
            local column=$(echo "$line" | sed -n 's/.*PRIMARY[[:space:]]\+KEY[[:space:]]*([[:space:]]*"\([^"]*\)"[[:space:]]*).*/\1/p' | head -1)
            
            
            if [[ -n "$table" && -n "$constraint" && -n "$column" ]]; then
                echo "ADD|PK|${table}|${constraint}|${column}"
            else
                # Fallback to implicit constraint name: column_name PRIMARY KEY
                local column=$(echo "$line" | sed -n 's/.*"*\([^"[:space:]]*\)"*[[:space:]]\+[^[:space:]]*[[:space:]]\+PRIMARY[[:space:]]\+KEY.*/\1/p' | head -1)
                if [[ -n "$table" && -n "$column" ]]; then
                    local constraint="${table}_pkey"
                    echo "ADD|PK|${table}|${constraint}|${column}"
                fi
            fi
        done
    fi
}

# Function to scan existing changelogs for constraint lifecycle
scan_existing_constraints() {
    local changelog_dir="$1"
    local -A constraint_states  # Tracks current state of each constraint
    local -A constraint_history  # Tracks full history of constraint operations
    
    echo "🔍 Scanning existing changelogs for constraint lifecycle..."
    
    # Find all SQL changelog files (excluding target file)
    while IFS= read -r -d '' file; do
        if [[ "$file" != "$TARGET_FILE" ]]; then
            echo "  📄 Scanning: $(basename "$file")"
            
            # Extract constraints from changesets
            local in_changeset=false
            local current_sql=""
            
            while IFS= read -r line; do
                if echo "$line" | grep -q "^[[:space:]]*--[[:space:]]*changeset"; then
                    # Process previous changeset if exists
                    if [[ "$in_changeset" = true && -n "$current_sql" ]]; then
                        process_constraint_operations "$current_sql" "constraint_states" "constraint_history"
                    fi
                    
                    # Start new changeset
                    in_changeset=true
                    current_sql=""
                elif [[ "$in_changeset" = true ]]; then
                    # Check for rollback comments
                    if echo "$line" | grep -q "^[[:space:]]*--[[:space:]]*rollback"; then
                        # Skip rollback lines
                        :
                    elif ! echo "$line" | grep -q "^[[:space:]]*--" && [[ -n "${line// }" ]]; then
                        # Add to current SQL
                        current_sql+="$line "
                    fi
                fi
            done < "$file"
            
            # Process last changeset
            if [[ "$in_changeset" = true && -n "$current_sql" ]]; then
                process_constraint_operations "$current_sql" "constraint_states" "constraint_history"
            fi
        fi
    done < <(find "$changelog_dir" -name "*.sql" -type f -print0 | sort -z)
    
    # Store constraint states in global arrays
    for constraint in "${!constraint_states[@]}"; do
        EXISTING_CONSTRAINTS["$constraint"]="${constraint_states[$constraint]}"
    done
    
    echo "✅ Found ${#EXISTING_CONSTRAINTS[@]} constraint states"
    
    for key in "${!EXISTING_CONSTRAINTS[@]}"; do
        echo "  - $key: ${EXISTING_CONSTRAINTS[$key]}"
    done
}

# Function to process constraint operations and update state
process_constraint_operations() {
    local sql="$1"
    local states_ref="$2"
    local history_ref="$3"
    
    # Extract constraints from SQL
    local constraint_info=$(extract_constraint_info "$sql")
    if [[ -n "$constraint_info" ]]; then
        process_single_constraint "$constraint_info" "$states_ref" "$history_ref"
    fi
    
    # Also check for inline constraints
    local inline_constraints=$(extract_inline_constraints "$sql")
    while IFS= read -r inline_constraint; do
        if [[ -n "$inline_constraint" ]]; then
            process_single_constraint "$inline_constraint" "$states_ref" "$history_ref"
        fi
    done <<< "$inline_constraints"
}

# Function to process a single constraint operation
process_single_constraint() {
    local constraint_info="$1"
    local states_ref="$2"
    local history_ref="$3"
    
    local IFS='|'
    read -r operation type table constraint rest <<< "$constraint_info"
    
    # Create constraint key (table + constraint name)
    local constraint_key="${table}|${constraint}"
    
    # Record in history
    eval "${history_ref}[\"$constraint_key\"]+=\"$constraint_info;\""
    
    # Update state based on operation
    case "$operation" in
        "ADD")
            eval "${states_ref}[\"$constraint_key\"]=\"EXISTS\""
            ;;
        "DROP")
            eval "${states_ref}[\"$constraint_key\"]=\"DROPPED\""
            ;;
    esac
}

# Function to check if a constraint already exists (considering lifecycle)
constraint_exists() {
    local constraint_info="$1"
    
    local IFS='|'
    read -r operation type table constraint rest <<< "$constraint_info"
    
    # Only check ADD operations for duplicates
    if [[ "$operation" != "ADD" ]]; then
        return 1
    fi
    
    
    # Create constraint key (table + constraint name)
    local constraint_key="${table}|${constraint}"
    
    # Check if constraint currently exists
    if [[ "${EXISTING_CONSTRAINTS[$constraint_key]}" == "EXISTS" ]]; then
        return 0
    fi
    
    # Check for foreign key constraints with different naming
    if [[ "$type" == "FK" ]]; then
        local column=$(echo "$rest" | cut -d'|' -f1)
        local ref_table=$(echo "$rest" | cut -d'|' -f2)
        local ref_column=$(echo "$rest" | cut -d'|' -f3)
        
        # Check for alternative constraint names
        local alt_constraint1="${table}_${column}_fkey"
        local alt_constraint2="${table}_${column}_fk"
        local alt_constraint3="${ref_table}_${ref_column}_fkey"
        
        for alt_constraint in "$alt_constraint1" "$alt_constraint2" "$alt_constraint3"; do
            local alt_key="${table}|${alt_constraint}"
            if [[ "${EXISTING_CONSTRAINTS[$alt_key]}" == "EXISTS" ]]; then
                return 0
            fi
        done
    fi
    
    # Check for primary key constraints with different naming
    if [[ "$type" == "PK" ]]; then
        local column=$(echo "$rest" | cut -d'|' -f1)
        
        # Check for alternative constraint names
        local alt_constraint1="${table}_pkey"
        local alt_constraint2="${table}_pk"
        local alt_constraint3="${table}_primary_key"
        
        for alt_constraint in "$alt_constraint1" "$alt_constraint2" "$alt_constraint3"; do
            local alt_key="${table}|${alt_constraint}"
            if [[ "${EXISTING_CONSTRAINTS[$alt_key]}" == "EXISTS" ]]; then
                return 0
            fi
        done
        
        # Also check for exact constraint name match regardless of column differences
        # This handles cases where the same constraint name is used but with different columns
        if [[ "${EXISTING_CONSTRAINTS[$constraint_key]}" == "EXISTS" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Function to process changelog file
process_changelog() {
    local filename="$1"
    local temp_file=$(mktemp)
    local removed_changesets=0
    local total_changesets=0
    local in_changeset=false
    local current_sql=""
    local current_changeset=""
    local should_remove=false
    local removed_constraint_type=""
    local removed_constraint_name=""
    
    echo "🔧 Processing changelog: $(basename "$filename")"
    
    # Read the file line by line
    while IFS= read -r line; do
        # Check if this is a changeset start
        if echo "$line" | grep -q "^[[:space:]]*--[[:space:]]*changeset"; then
            # Process previous changeset if we have one
            if [[ "$in_changeset" = true ]]; then
                if [[ "$should_remove" = false ]]; then
                    # Keep this changeset
                    echo "$current_changeset" >> "$temp_file"
                else
                    # Remove this changeset
                    removed_changesets=$((removed_changesets + 1))
                    local constraint_type_name=""
                    case "$removed_constraint_type" in
                        "FK") constraint_type_name="Foreign Key" ;;
                        "PK") constraint_type_name="Primary Key" ;;
                        "UQ") constraint_type_name="Unique" ;;
                        "CK") constraint_type_name="Check" ;;
                        *) constraint_type_name="Unknown" ;;
                    esac
                    echo "  🗑️  Removed duplicate $constraint_type_name constraint: $removed_constraint_name"
                fi
            fi
            
            # Start new changeset
            in_changeset=true
            current_sql=""
            current_changeset="$line"$'\n'
            should_remove=false
            total_changesets=$((total_changesets + 1))
        else
            if [[ "$in_changeset" = true ]]; then
                current_changeset+="$line"$'\n'
                
                # Check for rollback comments
                if echo "$line" | grep -q "^[[:space:]]*--[[:space:]]*rollback"; then
                    # Skip rollback lines for constraint detection
                    :
                elif ! echo "$line" | grep -q "^[[:space:]]*--" && [[ -n "${line// }" ]]; then
                    # Add to current SQL
                    current_sql+="$line "
                    
                    # Check if this line ends the SQL statement
                    if echo "$line" | grep -q ";$"; then
                        # Extract constraint info and check if it exists
                        local constraint_info=$(extract_constraint_info "$current_sql")
                        if [[ -n "$constraint_info" ]]; then
                            if constraint_exists "$constraint_info"; then
                                should_remove=true
                                # Extract constraint type and name for logging
                                local IFS='|'
                                read -r operation type table constraint rest <<< "$constraint_info"
                                removed_constraint_type="$type"
                                removed_constraint_name="$constraint"
                                echo "  ⚠️  Found duplicate constraint: $constraint_info"
                            fi
                        fi
                    fi
                fi
            else
                # Not in a changeset, just write the line
                echo "$line" >> "$temp_file"
            fi
        fi
    done < "$filename"
    
    # Process the last changeset if we have one
    if [[ "$in_changeset" = true ]]; then
        if [[ "$should_remove" = false ]]; then
            # Keep this changeset
            echo "$current_changeset" >> "$temp_file"
        else
            # Remove this changeset
            removed_changesets=$((removed_changesets + 1))
            local constraint_type_name=""
            case "$removed_constraint_type" in
                "FK") constraint_type_name="Foreign Key" ;;
                "PK") constraint_type_name="Primary Key" ;;
                "UQ") constraint_type_name="Unique" ;;
                "CK") constraint_type_name="Check" ;;
                *) constraint_type_name="Unknown" ;;
            esac
            echo "  🗑️  Removed duplicate $constraint_type_name constraint: $removed_constraint_name"
        fi
    fi
    
    # Replace original file with processed content
    mv "$temp_file" "$filename"
    
    echo "✅ Processing complete:"
    echo "   📊 Total changesets: $total_changesets"
    echo "   🗑️  Removed duplicates: $removed_changesets"
    echo "   ✅ Kept changesets: $((total_changesets - removed_changesets))"
}

# Main execution
main() {
    if [[ $# -lt 1 ]]; then
        show_usage
    fi
    
    local changelog_file="$1"
    local changelog_dir="${2:-./changelog}"
    
    if [[ ! -f "$changelog_file" ]]; then
        echo "❌ Error: Changelog file '$changelog_file' not found"
        exit 1
    fi
    
    if [[ ! -d "$changelog_dir" ]]; then
        echo "❌ Error: Changelog directory '$changelog_dir' not found"
        exit 1
    fi
    
    # Set global variables
    TARGET_FILE="$changelog_file"
    declare -A EXISTING_CONSTRAINTS
    
    echo "🚀 Starting constraint deduplication process..."
    echo "📁 Target file: $(basename "$changelog_file")"
    echo "📁 Changelog directory: $changelog_dir"
    echo ""
    
    # No backup needed - we'll modify the file in place
    
    # Scan existing constraints
    scan_existing_constraints "$changelog_dir"
    echo ""
    
    # Process the target file
    process_changelog "$changelog_file"
    echo ""
    
    echo "✅ Constraint deduplication complete!"
}

# Run main function with all arguments
main "$@"

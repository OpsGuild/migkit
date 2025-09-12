#!/bin/bash

# Script to fix changelog ordering issues
# Ensures columns are added before indexes are created on those columns

set -e

CHANGELOG_FILE="$1"

if [ -z "$CHANGELOG_FILE" ]; then
    echo "❌ Usage: $0 <changelog-file>"
    exit 1
fi

if [ ! -f "$CHANGELOG_FILE" ]; then
    echo "❌ Changelog file not found: $CHANGELOG_FILE"
    exit 1
fi

echo "🔧 Fixing changelog ordering in: $CHANGELOG_FILE"

# Create a temporary file for processing
TEMP_FILE=$(mktemp)
cp "$CHANGELOG_FILE" "$TEMP_FILE"

# Function to extract changeset content between markers
extract_changeset() {
    local start_marker="$1"
    local end_marker="$2"
    local file="$3"
    
    awk "/$start_marker/,/$end_marker/" "$file" | head -n -1 | tail -n +2
}

# Function to extract changeset ID from changeset header
get_changeset_id() {
    local changeset="$1"
    echo "$changeset" | head -n 1 | sed -n 's/.*changeset \([^:]*\):.*/\1/p'
}

# Arrays to store different types of changesets
declare -a column_changesets=()
declare -a index_changesets=()
declare -a constraint_changesets=()
declare -a table_changesets=()
declare -a other_changesets=()

# Parse the changelog and categorize changesets
current_changeset=""
in_changeset=false
changeset_id=""

while IFS= read -r line; do
    if [[ "$line" =~ ^--\ changeset.* ]]; then
        # Save previous changeset if exists
        if [ "$in_changeset" = true ] && [ -n "$current_changeset" ]; then
            # Categorize the changeset
            if [[ "$current_changeset" =~ ALTER\ TABLE.*ADD.*COLUMN ]] || [[ "$current_changeset" =~ ALTER\ TABLE.*ADD\ [^I] ]]; then
                column_changesets+=("$current_changeset")
            elif [[ "$current_changeset" =~ CREATE\ INDEX ]]; then
                index_changesets+=("$current_changeset")
            elif [[ "$current_changeset" =~ ALTER\ TABLE.*ADD\ CONSTRAINT ]] || [[ "$current_changeset" =~ ADD\ CONSTRAINT ]]; then
                constraint_changesets+=("$current_changeset")
            elif [[ "$current_changeset" =~ CREATE\ TABLE ]]; then
                table_changesets+=("$current_changeset")
            else
                other_changesets+=("$current_changeset")
            fi
        fi
        
        # Start new changeset
        current_changeset="$line"$'\n'
        in_changeset=true
        changeset_id=$(get_changeset_id "$line")
    elif [[ "$line" =~ ^--\ rollback.* ]]; then
        current_changeset+="$line"$'\n'
    elif [ "$in_changeset" = true ]; then
        current_changeset+="$line"$'\n'
    fi
done < "$TEMP_FILE"

# Save the last changeset
if [ "$in_changeset" = true ] && [ -n "$current_changeset" ]; then
    if [[ "$current_changeset" =~ ALTER\ TABLE.*ADD.*COLUMN ]] || [[ "$current_changeset" =~ ALTER\ TABLE.*ADD\ [^I] ]]; then
        column_changesets+=("$current_changeset")
    elif [[ "$current_changeset" =~ CREATE\ INDEX ]]; then
        index_changesets+=("$current_changeset")
    elif [[ "$current_changeset" =~ ALTER\ TABLE.*ADD\ CONSTRAINT ]] || [[ "$current_changeset" =~ ADD\ CONSTRAINT ]]; then
        constraint_changesets+=("$current_changeset")
    elif [[ "$current_changeset" =~ CREATE\ TABLE ]]; then
        table_changesets+=("$current_changeset")
    else
        other_changesets+=("$current_changeset")
    fi
fi

# Create the reordered changelog
{
    echo "-- liquibase formatted sql"
    echo ""
    
    # 1. First, create tables
    for changeset in "${table_changesets[@]}"; do
        echo "$changeset"
        echo ""
    done
    
    # 2. Then, add columns
    for changeset in "${column_changesets[@]}"; do
        echo "$changeset"
        echo ""
    done
    
    # 3. Then, create indexes
    for changeset in "${index_changesets[@]}"; do
        echo "$changeset"
        echo ""
    done
    
    # 4. Then, add constraints
    for changeset in "${constraint_changesets[@]}"; do
        echo "$changeset"
        echo ""
    done
    
    # 5. Finally, other changes
    for changeset in "${other_changesets[@]}"; do
        echo "$changeset"
        echo ""
    done
} > "$CHANGELOG_FILE"

# Clean up
rm "$TEMP_FILE"

echo "✅ Changelog ordering fixed!"
echo "📊 Reordered changesets:"
echo "   - Tables: ${#table_changesets[@]}"
echo "   - Columns: ${#column_changesets[@]}"
echo "   - Indexes: ${#index_changesets[@]}"
echo "   - Constraints: ${#constraint_changesets[@]}"
echo "   - Other: ${#other_changesets[@]}"

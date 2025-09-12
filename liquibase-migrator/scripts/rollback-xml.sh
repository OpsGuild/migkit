#!/bin/bash

set -e

# Configuration
SCRIPT_NAME="rollback-xml.sh"

# Function to show usage
show_usage() {
    echo "❌ Error: Please provide an XML changelog file path"
    echo "Usage: $SCRIPT_NAME <changelog-file>"
    exit 1
}

# Function to generate rollback XML for a changeset
generate_rollback_for_changeset() {
    local changeset_content="$1"
    local rollback_elements=""
    
    # Parse each line in the changeset
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -z "${line// }" ]] || echo "$line" | grep -q "^[[:space:]]*<!--"; then
            continue
        fi
        
        # Extract tag name (remove namespace if present)
        local tag_name=""
        if echo "$line" | grep -q "<[^:}]*:"; then
            tag_name=$(echo "$line" | sed -n 's/.*<[^:}]*:\([^[:space:]>]*\).*/\1/p')
        else
            tag_name=$(echo "$line" | sed -n 's/.*<\([^[:space:]>]*\).*/\1/p')
        fi
        
        # Skip closing tags and non-action tags
        if [[ "$tag_name" =~ ^/ ]] || [[ "$tag_name" =~ ^(changeSet|column|constraints)$ ]]; then
            continue
        fi
        
        case "$tag_name" in
            "createTable")
                local table_name=$(echo "$line" | sed -n 's/.*tableName="\([^"]*\)".*/\1/p')
                if [[ -n "$table_name" ]]; then
                    rollback_elements+="        <dropTable tableName=\"$table_name\"/>"$'\n'
                fi
                ;;
            "addColumn")
                local table_name=$(echo "$line" | sed -n 's/.*tableName="\([^"]*\)".*/\1/p')
                # For addColumn, we need to look at the column element
                if [[ -n "$table_name" ]]; then
                    # This is a simplified approach - in practice, you'd need to parse the column element
                    rollback_elements+="        <dropColumn tableName=\"$table_name\" columnName=\"column_name\"/>"$'\n'
                fi
                ;;
            "addUniqueConstraint")
                # Handle multi-line elements by extracting from the entire changeset content
                local table_name=$(echo "$changeset_content" | sed -n 's/.*tableName="\([^"]*\)".*/\1/p' | head -1)
                local constraint_name=$(echo "$changeset_content" | sed -n 's/.*constraintName="\([^"]*\)".*/\1/p' | head -1)
                if [[ -n "$table_name" && -n "$constraint_name" ]]; then
                    rollback_elements+="        <dropUniqueConstraint tableName=\"$table_name\" constraintName=\"$constraint_name\"/>"$'\n'
                fi
                ;;
            "addForeignKeyConstraint")
                local table_name=$(echo "$line" | sed -n 's/.*baseTableName="\([^"]*\)".*/\1/p')
                local constraint_name=$(echo "$line" | sed -n 's/.*constraintName="\([^"]*\)".*/\1/p')
                if [[ -n "$table_name" && -n "$constraint_name" ]]; then
                    rollback_elements+="        <dropForeignKeyConstraint baseTableName=\"$table_name\" constraintName=\"$constraint_name\"/>"$'\n'
                fi
                ;;
            "addNotNullConstraint")
                local table_name=$(echo "$line" | sed -n 's/.*tableName="\([^"]*\)".*/\1/p')
                local column_name=$(echo "$line" | sed -n 's/.*columnName="\([^"]*\)".*/\1/p')
                if [[ -n "$table_name" && -n "$column_name" ]]; then
                    rollback_elements+="        <dropNotNullConstraint tableName=\"$table_name\" columnName=\"$column_name\"/>"$'\n'
                fi
                ;;
            "createIndex")
                local table_name=$(echo "$line" | sed -n 's/.*tableName="\([^"]*\)".*/\1/p')
                local index_name=$(echo "$line" | sed -n 's/.*indexName="\([^"]*\)".*/\1/p')
                if [[ -n "$table_name" && -n "$index_name" ]]; then
                    rollback_elements+="        <dropIndex tableName=\"$table_name\" indexName=\"$index_name\"/>"$'\n'
                fi
                ;;
            "addPrimaryKey")
                local table_name=$(echo "$line" | sed -n 's/.*tableName="\([^"]*\)".*/\1/p')
                local constraint_name=$(echo "$line" | sed -n 's/.*constraintName="\([^"]*\)".*/\1/p')
                if [[ -n "$table_name" && -n "$constraint_name" ]]; then
                    rollback_elements+="        <dropPrimaryKey tableName=\"$table_name\" constraintName=\"$constraint_name\"/>"$'\n'
                fi
                ;;
            "addCheckConstraint")
                local table_name=$(echo "$line" | sed -n 's/.*tableName="\([^"]*\)".*/\1/p')
                local constraint_name=$(echo "$line" | sed -n 's/.*constraintName="\([^"]*\)".*/\1/p')
                if [[ -n "$table_name" && -n "$constraint_name" ]]; then
                    rollback_elements+="        <dropCheckConstraint tableName=\"$table_name\" constraintName=\"$constraint_name\"/>"$'\n'
                fi
                ;;
            "addDefaultValue")
                local table_name=$(echo "$line" | sed -n 's/.*tableName="\([^"]*\)".*/\1/p')
                local column_name=$(echo "$line" | sed -n 's/.*columnName="\([^"]*\)".*/\1/p')
                if [[ -n "$table_name" && -n "$column_name" ]]; then
                    rollback_elements+="        <dropDefaultValue tableName=\"$table_name\" columnName=\"$column_name\"/>"$'\n'
                fi
                ;;
            "renameColumn")
                local table_name=$(echo "$line" | sed -n 's/.*tableName="\([^"]*\)".*/\1/p')
                local old_column_name=$(echo "$line" | sed -n 's/.*oldColumnName="\([^"]*\)".*/\1/p')
                local new_column_name=$(echo "$line" | sed -n 's/.*newColumnName="\([^"]*\)".*/\1/p')
                if [[ -n "$table_name" && -n "$old_column_name" && -n "$new_column_name" ]]; then
                    rollback_elements+="        <renameColumn tableName=\"$table_name\" oldColumnName=\"$new_column_name\" newColumnName=\"$old_column_name\"/>"$'\n'
                fi
                ;;
            "renameTable")
                local old_table_name=$(echo "$line" | sed -n 's/.*oldTableName="\([^"]*\)".*/\1/p')
                local new_table_name=$(echo "$line" | sed -n 's/.*newTableName="\([^"]*\)".*/\1/p')
                if [[ -n "$old_table_name" && -n "$new_table_name" ]]; then
                    rollback_elements+="        <renameTable oldTableName=\"$new_table_name\" newTableName=\"$old_table_name\"/>"$'\n'
                fi
                ;;
            "modifyDataType")
                local table_name=$(echo "$line" | sed -n 's/.*tableName="\([^"]*\)".*/\1/p')
                local column_name=$(echo "$line" | sed -n 's/.*columnName="\([^"]*\)".*/\1/p')
                if [[ -n "$table_name" && -n "$column_name" ]]; then
                    rollback_elements+="        <comment>-- Rollback for modifyDataType requires manual intervention (table: $table_name, column: $column_name)</comment>"$'\n'
                fi
                ;;
            *)
                if [[ -n "$tag_name" ]]; then
                    rollback_elements+="        <comment>-- Rollback for $tag_name requires manual intervention</comment>"$'\n'
                fi
                ;;
        esac
    done <<< "$changeset_content"
    
    echo "$rollback_elements"
}

# Function to process XML changelog file
process_xml_changelog() {
    local filename="$1"
    local temp_file=$(mktemp)
    local added_rollbacks=0
    local skipped_rollbacks=0
    local total_changesets=0
    local in_changeset=false
    local changeset_content=""
    local changeset_indent=""
    
    # Read the file line by line
    while IFS= read -r line; do
        # Check if this is a changeset start
        if echo "$line" | grep -q "<[^:}]*:changeSet\|<changeSet"; then
            in_changeset=true
            changeset_content="$line"$'\n'
            # Extract indentation
            changeset_indent=$(echo "$line" | sed 's/[^[:space:]].*//')
            total_changesets=$((total_changesets + 1))
            continue
        fi
        
        # If we're in a changeset, collect content
        if [[ "$in_changeset" = true ]]; then
            changeset_content+="$line"$'\n'
            
            # Check if this is the end of the changeset
            if echo "$line" | grep -q "</[^:}]*:changeSet>\|</changeSet>"; then
                in_changeset=false
                
                # Check if there's already a rollback element
                if echo "$changeset_content" | grep -q "<[^:}]*:rollback\|<rollback"; then
                    skipped_rollbacks=$((skipped_rollbacks + 1))
                    echo "$changeset_content" >> "$temp_file"
                else
                    # Generate rollback elements
                    local rollback_elements=$(generate_rollback_for_changeset "$changeset_content")
                    
                    if [[ -n "$rollback_elements" ]]; then
                        # Add rollback element before closing changeset
                        local rollback_start="${changeset_indent}    <rollback>"
                        local rollback_end="${changeset_indent}    </rollback>"
                        
                        # Remove the last line (closing changeset) temporarily
                        local changeset_without_close=$(echo "$changeset_content" | head -n -1)
                        
                        echo "$changeset_without_close" >> "$temp_file"
                        echo "$rollback_start" >> "$temp_file"
                        echo -n "$rollback_elements" >> "$temp_file"
                        echo "$rollback_end" >> "$temp_file"
                        echo "$line" >> "$temp_file"  # Add the closing changeset tag
                        
                        added_rollbacks=$((added_rollbacks + 1))
                    else
                        echo "$changeset_content" >> "$temp_file"
                    fi
                fi
                changeset_content=""
            fi
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$filename"
    
    # Replace original file with processed content
    mv "$temp_file" "$filename"
    
    echo "📊 Processed $total_changesets changesets:"
    echo "   ✅ Added rollbacks to $added_rollbacks changesets"
    echo "   ⏭️  Skipped $skipped_rollbacks changesets (already have rollbacks)"
}

# Function to validate XML file
validate_xml() {
    local filename="$1"
    
    # Basic XML validation using xmllint if available
    if command -v xmllint >/dev/null 2>&1; then
        if ! xmllint --noout "$filename" 2>/dev/null; then
            echo "⚠️  Warning: XML validation failed. The file may have syntax errors."
            return 1
        fi
    fi
    
    return 0
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
    
    echo "🔧 Adding rollback statements to XML changelog $changelog_file..."
    
    # Validate XML before processing
    if ! validate_xml "$changelog_file"; then
        echo "⚠️  Proceeding with processing despite XML validation warnings..."
    fi
    
    process_xml_changelog "$changelog_file"
    echo "✅ Rollback statements added successfully!"
    echo "⚠️  Note: Please review generated rollback statements for accuracy"
    echo "⚠️  Some complex changes may require manual rollback statements"
}

# Run main function with all arguments
main "$@"
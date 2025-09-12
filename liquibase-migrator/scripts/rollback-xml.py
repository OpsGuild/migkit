#!/usr/bin/env python3

import os
import re
import sys
import xml.etree.ElementTree as ET


def generate_rollback_for_changeset(changeset):
    """Generate rollback XML for a given changeset"""
    rollback_elements = []

    for child in changeset:
        tag_name = child.tag.split("}")[-1] if "}" in child.tag else child.tag

        if tag_name == "createTable":
            table_name = child.get("tableName")
            rollback = ET.Element("dropTable")
            rollback.set("tableName", table_name)
            rollback_elements.append(rollback)

        elif tag_name == "addColumn":
            table_name = child.get("tableName")
            column_elem = child.find(
                "{http://www.liquibase.org/xml/ns/dbchangelog}column"
            )
            if column_elem is not None:
                column_name = column_elem.get("name")
                rollback = ET.Element("dropColumn")
                rollback.set("tableName", table_name)
                rollback.set("columnName", column_name)
                rollback_elements.append(rollback)

        elif tag_name == "addUniqueConstraint":
            table_name = child.get("tableName")
            constraint_name = child.get("constraintName")
            rollback = ET.Element("dropUniqueConstraint")
            rollback.set("tableName", table_name)
            rollback.set("constraintName", constraint_name)
            rollback_elements.append(rollback)

        elif tag_name == "addForeignKeyConstraint":
            table_name = child.get("baseTableName")
            constraint_name = child.get("constraintName")
            rollback = ET.Element("dropForeignKeyConstraint")
            rollback.set("baseTableName", table_name)
            rollback.set("constraintName", constraint_name)
            rollback_elements.append(rollback)

        elif tag_name == "addNotNullConstraint":
            table_name = child.get("tableName")
            column_name = child.get("columnName")
            rollback = ET.Element("dropNotNullConstraint")
            rollback.set("tableName", table_name)
            rollback.set("columnName", column_name)
            rollback_elements.append(rollback)

        elif tag_name == "createIndex":
            table_name = child.get("tableName")
            index_name = child.get("indexName")
            rollback = ET.Element("dropIndex")
            rollback.set("tableName", table_name)
            rollback.set("indexName", index_name)
            rollback_elements.append(rollback)

        elif tag_name == "addPrimaryKey":
            table_name = child.get("tableName")
            constraint_name = child.get("constraintName")
            rollback = ET.Element("dropPrimaryKey")
            rollback.set("tableName", table_name)
            rollback.set("constraintName", constraint_name)
            rollback_elements.append(rollback)

        elif tag_name == "addCheckConstraint":
            table_name = child.get("tableName")
            constraint_name = child.get("constraintName")
            rollback = ET.Element("dropCheckConstraint")
            rollback.set("tableName", table_name)
            rollback.set("constraintName", constraint_name)
            rollback_elements.append(rollback)

        elif tag_name == "addDefaultValue":
            table_name = child.get("tableName")
            column_name = child.get("columnName")
            rollback = ET.Element("dropDefaultValue")
            rollback.set("tableName", table_name)
            rollback.set("columnName", column_name)
            rollback_elements.append(rollback)

        elif tag_name == "renameColumn":
            table_name = child.get("tableName")
            old_column_name = child.get("oldColumnName")
            new_column_name = child.get("newColumnName")
            rollback = ET.Element("renameColumn")
            rollback.set("tableName", table_name)
            rollback.set("oldColumnName", new_column_name)
            rollback.set("newColumnName", old_column_name)
            rollback_elements.append(rollback)

        elif tag_name == "renameTable":
            old_table_name = child.get("oldTableName")
            new_table_name = child.get("newTableName")
            rollback = ET.Element("renameTable")
            rollback.set("oldTableName", new_table_name)
            rollback.set("newTableName", old_table_name)
            rollback_elements.append(rollback)

        elif tag_name == "modifyDataType":
            table_name = child.get("tableName")
            column_name = child.get("columnName")
            new_data_type = child.get("newDataType")
            rollback = ET.Element("comment")
            rollback.text = f"-- Rollback for modifyDataType requires manual intervention (table: {table_name}, column: {column_name})"
            rollback_elements.append(rollback)

        else:
            rollback = ET.Element("comment")
            rollback.text = (
                f"-- Rollback for {tag_name} requires manual intervention"
            )
            rollback_elements.append(rollback)

    return rollback_elements


def process_xml_changelog(filename):
    """Process an XML changelog file and add rollback statements"""
    try:
        tree = ET.parse(filename)
        root = tree.getroot()
    except ET.ParseError as e:
        print(f"❌ Error parsing XML file: {e}")
        return False

    changesets = root.findall(
        ".//{http://www.liquibase.org/xml/ns/dbchangelog}changeSet"
    )

    added_rollbacks = 0
    skipped_rollbacks = 0

    for changeset in changesets:
        # Check for existing rollback element
        existing_rollback = changeset.find(
            "{http://www.liquibase.org/xml/ns/dbchangelog}rollback"
        )
        if existing_rollback is not None:
            skipped_rollbacks += 1
            continue

        rollback_elements = generate_rollback_for_changeset(changeset)

        if rollback_elements:
            rollback = ET.Element(
                "{http://www.liquibase.org/xml/ns/dbchangelog}rollback"
            )

            for element in rollback_elements:
                rollback.append(element)

            changeset.append(rollback)
            added_rollbacks += 1

    print(f"📊 Processed {len(changesets)} changesets:")
    print(f"   ✅ Added rollbacks to {added_rollbacks} changesets")
    print(f"   ⏭️  Skipped {skipped_rollbacks} changesets (already have rollbacks)")

    try:
        ET.indent(tree, space="  ", level=0)
        tree.write(filename, encoding="utf-8", xml_declaration=True)
        return True
    except Exception as e:
        print(f"❌ Error writing XML file: {e}")
        return False


def main():
    if len(sys.argv) != 2:
        print("❌ Error: Please provide an XML changelog file path")
        print("Usage: python3 rollback-xml.py <changelog-file>")
        sys.exit(1)

    changelog_file = sys.argv[1]

    if not os.path.exists(changelog_file):
        print(f"❌ Error: Changelog file '{changelog_file}' not found")
        sys.exit(1)

    print(
        f"🔧 Adding rollback statements to XML changelog {changelog_file}..."
    )

    if process_xml_changelog(changelog_file):
        print("✅ Rollback statements added successfully!")
        print(
            "⚠️  Note: Please review generated rollback statements for accuracy"
        )
        print("⚠️  Some complex changes may require manual rollback statements")
    else:
        print("❌ Failed to add rollback statements")
        sys.exit(1)


if __name__ == "__main__":
    main()

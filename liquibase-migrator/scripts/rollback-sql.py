#!/usr/bin/env python3

import os
import re
import sys


def extract_table_name(sql):
    """Extract table name from various SQL statements"""
    patterns = [
        r'CREATE\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s(]+)"?',
        r'ALTER\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?',
        r'DROP\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?',
        r'TRUNCATE\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?',
        r'INSERT\s+INTO\s+"?([^"\s]+)"?\."?([^"\s]+)"?',
        r'UPDATE\s+"?([^"\s]+)"?\."?([^"\s]+)"?',
        r'DELETE\s+FROM\s+"?([^"\s]+)"?\."?([^"\s]+)"?',
    ]

    for pattern in patterns:
        match = re.search(pattern, sql, re.IGNORECASE)
        if match:
            schema = match.group(1)
            table = match.group(2)
            if schema and table and schema != "TABLE":
                return f'"{schema}"."{table}"'
            elif table:
                return f'"{table}"'

    return None


def extract_column_info(sql):
    """Extract table and column info from various column operations"""
    patterns = [
        r'ALTER\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?\s+ADD\s+COLUMN\s+"?([^"\s]+)"?',
        r'ALTER\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?\s+ADD\s+"?([^"\s]+)"?',
        r'ALTER\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?\s+DROP\s+COLUMN\s+"?([^"\s]+)"?',
        r'ALTER\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?\s+ALTER\s+COLUMN\s+"?([^"\s]+)"?',
        r'ALTER\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?\s+RENAME\s+COLUMN\s+"?([^"\s]+)"?',
    ]

    for pattern in patterns:
        match = re.search(pattern, sql, re.IGNORECASE)
        if match:
            schema = match.group(1)
            table = match.group(2)
            column = match.group(3)

            if schema and table and schema != "TABLE":
                return f'"{schema}"."{table}"', f'"{column}"'
            elif table:
                return f'"{table}"', f'"{column}"'

    return None, None


def extract_constraint_info(sql):
    """Extract table and constraint info from constraint operations"""
    patterns = [
        r'ALTER\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?\s+ADD\s+CONSTRAINT\s+"?([^"\s]+)"?',
        r'ALTER\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?\s+DROP\s+CONSTRAINT\s+"?([^"\s]+)"?',
        r'ALTER\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?\s+ADD\s+PRIMARY\s+KEY\s+"?([^"\s]+)"?',
        r'ALTER\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?\s+DROP\s+PRIMARY\s+KEY\s+"?([^"\s]+)"?',
    ]

    for pattern in patterns:
        match = re.search(pattern, sql, re.IGNORECASE)
        if match:
            schema = match.group(1)
            table = match.group(2)
            constraint = match.group(3)

            if schema and table and schema != "TABLE":
                return f'"{schema}"."{table}"', f'"{constraint}"'
            elif table:
                return f'"{table}"', f'"{constraint}"'

    return None, None


def extract_index_info(sql):
    """Extract index info from index operations"""
    patterns = [
        r'CREATE\s+(?:UNIQUE\s+)?INDEX\s+"?([^"\s]+)"?\s+ON\s+"?([^"\s]+)"?\."?([^"\s]+)"?',
        r'CREATE\s+(?:UNIQUE\s+)?INDEX\s+"?([^"\s]+)"?\s+ON\s+"?([^"\s]+)"?',
        r'DROP\s+INDEX\s+"?([^"\s]+)"?',
        r'DROP\s+INDEX\s+"?([^"\s]+)"?\s+ON\s+"?([^"\s]+)"?\."?([^"\s]+)"?',
    ]

    for pattern in patterns:
        match = re.search(pattern, sql, re.IGNORECASE)
        if match:
            index_name = match.group(1)
            if len(match.groups()) > 1:
                schema = match.group(2) if len(match.groups()) > 2 else None
                table = (
                    match.group(3)
                    if len(match.groups()) > 2
                    else match.group(2)
                )
                if schema and table and schema != "INDEX":
                    return f'"{index_name}"', f'"{schema}"."{table}"'
                elif table:
                    return f'"{index_name}"', f'"{table}"'
            return f'"{index_name}"', None

    return None, None


def generate_rollback(sql):
    """Generate comprehensive rollback SQL for a given SQL statement"""
    sql_upper = sql.upper().strip()
    sql_clean = re.sub(r"\s+", " ", sql).strip()

    if sql_upper.startswith("CREATE TABLE"):
        table_name = extract_table_name(sql)
        if table_name:
            return f"DROP TABLE IF EXISTS {table_name};"

    elif sql_upper.startswith("DROP TABLE"):
        table_name = extract_table_name(sql)
        if table_name:
            return f"-- Rollback for DROP TABLE {table_name} requires original table definition"

    elif (
        "ALTER TABLE" in sql_upper
        and "ADD" in sql_upper
        and "COLUMN" in sql_upper
    ):
        table_name, column_name = extract_column_info(sql)
        if table_name and column_name:
            return f"ALTER TABLE {table_name} DROP COLUMN IF EXISTS {column_name};"

    elif (
        "ALTER TABLE" in sql_upper
        and "DROP" in sql_upper
        and "COLUMN" in sql_upper
    ):
        table_name, column_name = extract_column_info(sql)
        if table_name and column_name:
            return f"-- Rollback for DROP COLUMN {column_name} requires original column definition"

    elif "ALTER TABLE" in sql_upper and "ADD CONSTRAINT" in sql_upper:
        table_name, constraint_name = extract_constraint_info(sql)
        if table_name and constraint_name:
            return f"ALTER TABLE {table_name} DROP CONSTRAINT IF EXISTS {constraint_name};"

    elif "ALTER TABLE" in sql_upper and "DROP CONSTRAINT" in sql_upper:
        table_name, constraint_name = extract_constraint_info(sql)
        if table_name and constraint_name:
            return f"-- Rollback for DROP CONSTRAINT {constraint_name} requires original constraint definition"

    elif "ALTER TABLE" in sql_upper and "ADD PRIMARY KEY" in sql_upper:
        table_name = extract_table_name(sql)
        if table_name:
            return f'ALTER TABLE {table_name} DROP CONSTRAINT IF EXISTS {table_name.replace(".", "_")}_pkey;'

    elif "ALTER TABLE" in sql_upper and "DROP PRIMARY KEY" in sql_upper:
        table_name = extract_table_name(sql)
        if table_name:
            return f"-- Rollback for DROP PRIMARY KEY requires original primary key definition"

    elif "ALTER TABLE" in sql_upper and "ADD FOREIGN KEY" in sql_upper:
        table_name, constraint_name = extract_constraint_info(sql)
        if table_name and constraint_name:
            return f"ALTER TABLE {table_name} DROP CONSTRAINT IF EXISTS {constraint_name};"

    elif "ALTER TABLE" in sql_upper and "DROP FOREIGN KEY" in sql_upper:
        table_name, constraint_name = extract_constraint_info(sql)
        if table_name and constraint_name:
            return f"-- Rollback for DROP FOREIGN KEY requires original foreign key definition"

    elif "ALTER TABLE" in sql_upper and "ADD UNIQUE" in sql_upper:
        table_name, constraint_name = extract_constraint_info(sql)
        if table_name and constraint_name:
            return f"ALTER TABLE {table_name} DROP CONSTRAINT IF EXISTS {constraint_name};"

    elif "ALTER TABLE" in sql_upper and "DROP UNIQUE" in sql_upper:
        table_name, constraint_name = extract_constraint_info(sql)
        if table_name and constraint_name:
            return f"-- Rollback for DROP UNIQUE requires original unique constraint definition"

    elif "ALTER TABLE" in sql_upper and "ADD CHECK" in sql_upper:
        table_name, constraint_name = extract_constraint_info(sql)
        if table_name and constraint_name:
            return f"ALTER TABLE {table_name} DROP CONSTRAINT IF EXISTS {constraint_name};"

    elif "ALTER TABLE" in sql_upper and "DROP CHECK" in sql_upper:
        table_name, constraint_name = extract_constraint_info(sql)
        if table_name and constraint_name:
            return f"-- Rollback for DROP CHECK requires original check constraint definition"

    elif (
        "ALTER TABLE" in sql_upper
        and "ALTER COLUMN" in sql_upper
        and "SET NOT NULL" in sql_upper
    ):
        table_name, column_name = extract_column_info(sql)
        if table_name and column_name:
            return f"ALTER TABLE {table_name} ALTER COLUMN {column_name} DROP NOT NULL;"

    elif (
        "ALTER TABLE" in sql_upper
        and "ALTER COLUMN" in sql_upper
        and "DROP NOT NULL" in sql_upper
    ):
        table_name, column_name = extract_column_info(sql)
        if table_name and column_name:
            return f"ALTER TABLE {table_name} ALTER COLUMN {column_name} SET NOT NULL;"

    elif (
        "ALTER TABLE" in sql_upper
        and "ALTER COLUMN" in sql_upper
        and "SET DEFAULT" in sql_upper
    ):
        table_name, column_name = extract_column_info(sql)
        if table_name and column_name:
            return f"ALTER TABLE {table_name} ALTER COLUMN {column_name} DROP DEFAULT;"

    elif (
        "ALTER TABLE" in sql_upper
        and "ALTER COLUMN" in sql_upper
        and "DROP DEFAULT" in sql_upper
    ):
        table_name, column_name = extract_column_info(sql)
        if table_name and column_name:
            return (
                f"-- Rollback for DROP DEFAULT requires original default value"
            )

    elif (
        "ALTER TABLE" in sql_upper
        and "ALTER COLUMN" in sql_upper
        and "TYPE" in sql_upper
    ):
        table_name, column_name = extract_column_info(sql)
        if table_name and column_name:
            return f"-- Rollback for ALTER COLUMN TYPE requires original column type"

    elif "ALTER TABLE" in sql_upper and "RENAME COLUMN" in sql_upper:
        match = re.search(
            r'ALTER\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?\s+RENAME\s+COLUMN\s+"?([^"\s]+)"?\s+TO\s+"?([^"\s]+)"?',
            sql,
            re.IGNORECASE,
        )
        if match:
            schema = match.group(1)
            table = match.group(2)
            old_column = match.group(3)
            new_column = match.group(4)

            if schema and table and schema != "TABLE":
                table_name = f'"{schema}"."{table}"'
            else:
                table_name = f'"{table}"'

            return f'ALTER TABLE {table_name} RENAME COLUMN "{new_column}" TO "{old_column}";'

    elif "ALTER TABLE" in sql_upper and "RENAME TO" in sql_upper:
        match = re.search(
            r'ALTER\s+TABLE\s+"?([^"\s]+)"?\."?([^"\s]+)"?\s+RENAME\s+TO\s+"?([^"\s]+)"?',
            sql,
            re.IGNORECASE,
        )
        if match:
            schema = match.group(1)
            old_table = match.group(2)
            new_table = match.group(3)

            if schema and old_table and schema != "TABLE":
                old_table_name = f'"{schema}"."{old_table}"'
            else:
                old_table_name = f'"{old_table}"'

            return f'ALTER TABLE "{new_table}" RENAME TO {old_table_name};'

    elif sql_upper.startswith("CREATE") and "INDEX" in sql_upper:
        index_name, table_name = extract_index_info(sql)
        if index_name:
            return f"DROP INDEX IF EXISTS {index_name};"

    elif sql_upper.startswith("DROP") and "INDEX" in sql_upper:
        index_name, table_name = extract_index_info(sql)
        if index_name:
            return f"-- Rollback for DROP INDEX requires original index definition"

    elif sql_upper.startswith("CREATE SEQUENCE"):
        match = re.search(
            r'CREATE\s+SEQUENCE\s+"?([^"\s]+)"?\."?([^"\s]+)"?',
            sql,
            re.IGNORECASE,
        )
        if match:
            schema = match.group(1)
            sequence = match.group(2)
            if schema and sequence:
                sequence_name = f'"{schema}"."{sequence}"'
            else:
                sequence_name = f'"{match.group(1)}"'
            return f"DROP SEQUENCE IF EXISTS {sequence_name};"

    elif sql_upper.startswith("DROP SEQUENCE"):
        match = re.search(
            r'DROP\s+SEQUENCE\s+"?([^"\s]+)"?', sql, re.IGNORECASE
        )
        if match:
            sequence_name = match.group(1)
            return f"-- Rollback for DROP SEQUENCE requires original sequence definition"

    elif sql_upper.startswith("CREATE VIEW"):
        match = re.search(
            r'CREATE\s+VIEW\s+"?([^"\s]+)"?\."?([^"\s]+)"?', sql, re.IGNORECASE
        )
        if match:
            schema = match.group(1)
            view = match.group(2)
            if schema and view:
                view_name = f'"{schema}"."{view}"'
            else:
                view_name = f'"{match.group(1)}"'
            return f"DROP VIEW IF EXISTS {view_name};"

    elif sql_upper.startswith("DROP VIEW"):
        match = re.search(r'DROP\s+VIEW\s+"?([^"\s]+)"?', sql, re.IGNORECASE)
        if match:
            view_name = match.group(1)
            return (
                f"-- Rollback for DROP VIEW requires original view definition"
            )

    elif sql_upper.startswith("CREATE FUNCTION"):
        match = re.search(
            r'CREATE\s+FUNCTION\s+"?([^"\s(]+)"?', sql, re.IGNORECASE
        )
        if match:
            function_name = match.group(1)
            return f'DROP FUNCTION IF EXISTS "{function_name}";'

    elif sql_upper.startswith("DROP FUNCTION"):
        match = re.search(
            r'DROP\s+FUNCTION\s+"?([^"\s(]+)"?', sql, re.IGNORECASE
        )
        if match:
            function_name = match.group(1)
            return f"-- Rollback for DROP FUNCTION requires original function definition"

    elif sql_upper.startswith("CREATE TRIGGER"):
        match = re.search(
            r'CREATE\s+TRIGGER\s+"?([^"\s]+)"?', sql, re.IGNORECASE
        )
        if match:
            trigger_name = match.group(1)
            return f'DROP TRIGGER IF EXISTS "{trigger_name}";'

    elif sql_upper.startswith("DROP TRIGGER"):
        match = re.search(
            r'DROP\s+TRIGGER\s+"?([^"\s]+)"?', sql, re.IGNORECASE
        )
        if match:
            trigger_name = match.group(1)
            return f"-- Rollback for DROP TRIGGER requires original trigger definition"

    elif sql_upper.startswith("INSERT"):
        table_name = extract_table_name(sql)
        if table_name:
            return f"-- Rollback for INSERT requires identifying the inserted record(s)"

    elif sql_upper.startswith("UPDATE"):
        table_name = extract_table_name(sql)
        if table_name:
            return f"-- Rollback for UPDATE requires original values"

    elif sql_upper.startswith("DELETE"):
        table_name = extract_table_name(sql)
        if table_name:
            return f"-- Rollback for DELETE requires original values"

    elif sql_upper.startswith("TRUNCATE"):
        table_name = extract_table_name(sql)
        if table_name:
            return f"-- Rollback for TRUNCATE requires original data"

    return "-- Empty rollback (manual intervention required)"


def process_changelog(filename):
    """Process a changelog file and add rollback statements"""
    with open(filename, "r") as f:
        lines = f.readlines()

    output_lines = []
    i = 0
    added_rollbacks = 0
    skipped_rollbacks = 0
    total_changesets = 0

    while i < len(lines):
        line = lines[i]
        output_lines.append(line)

        if re.match(r"^\s*--\s+changeset", line):
            total_changesets += 1
            j = i + 1
            sql_lines = []
            has_rollback = False

            # First pass: collect SQL lines and check for existing rollback
            while j < len(lines):
                next_line = lines[j]

                if (
                    re.match(r"^\s*--\s+changeset", next_line)
                    or next_line.strip() == ""
                ):
                    break

                if re.match(r"^\s*--\s*rollback", next_line):
                    has_rollback = True
                    break

                if not re.match(r"^\s*--", next_line) and next_line.strip():
                    sql_lines.append(next_line.strip())

                j += 1

            # Second pass: add all lines including existing rollback
            j = i + 1
            while j < len(lines):
                next_line = lines[j]

                if (
                    re.match(r"^\s*--\s+changeset", next_line)
                    or next_line.strip() == ""
                ):
                    break

                output_lines.append(next_line)
                j += 1

            # Only add rollback if we have SQL and no existing rollback
            if sql_lines and not has_rollback:
                sql = " ".join(sql_lines)
                rollback_sql = generate_rollback(sql)
                output_lines.append(f"-- rollback {rollback_sql}\n")
                added_rollbacks += 1
            elif has_rollback:
                skipped_rollbacks += 1

            i = j
        else:
            i += 1

    print(f"📊 Processed {total_changesets} changesets:")
    print(f"   ✅ Added rollbacks to {added_rollbacks} changesets")
    print(f"   ⏭️  Skipped {skipped_rollbacks} changesets (already have rollbacks)")

    with open(filename, "w") as f:
        f.writelines(output_lines)


def main():
    if len(sys.argv) != 2:
        print("❌ Error: Please provide a changelog file path")
        print("Usage: python3 rollback-sql.py <changelog-file>")
        sys.exit(1)

    changelog_file = sys.argv[1]

    if not os.path.exists(changelog_file):
        print(f"❌ Error: Changelog file '{changelog_file}' not found")
        sys.exit(1)

    process_changelog(changelog_file)
    print("✅ Comprehensive rollback statements added successfully!")
    print("⚠️  Note: Please review generated rollback statements for accuracy")
    print("⚠️  Some complex changes may require manual rollback statements")


if __name__ == "__main__":
    main()

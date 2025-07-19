#!/bin/bash
# -----------------------------------------------------------------------------
# Script: db_operations.sh
# Purpose: Provides functions for performing database-specific operations,
#          such as dumping databases.
# Developed by: Jules (AI Assistant)
# Copyright: (c) 2025 Alejandro Capuro. All rights reserved.
# File Version: 20250718.140000
# Project Version: 1.0.0
#
# Notes:
#   - This script is intended to be sourced by other scripts (e.g., actual_backup.sh).
#   - It supports MySQL, MariaDB, PostgreSQL, and MongoDB for dumping.
# -----------------------------------------------------------------------------

# --- Logging Helper Function ---
# Function: _log_db_message
# Purpose: Standardized logging helper for messages from this script.
# Arguments: $1 - Log level (INFO, WARN, ERROR)
#            $2 - Message to log
_log_db_message() {
    local level="$1"
    local message="$2"
    # Direct all messages to standard error (stderr)
    case "$level" in
        INFO)  echo "[DB_OPERATIONS] INFO $message" >&2 ;;
        WARN)  echo "[DB_OPERATIONS] WARN $message" >&2 ;;
        ERROR) echo "[DB_OPERATIONS] ERROR $message" >&2 ;;
        *)     echo "[DB_OPERATIONS] UNKNOWN $message" >&2 ;;
    esac
}

# Function: perform_dump
# Purpose: Dumps a specified database to a file based on its type.
# Arguments:
#   $1: db_type (string) - Type of the database (e.g., "mysql", "mariadb", "postgres", "mongodb")
#   $2: db_name (string) - Name of the database to dump
#   $3: db_user (string) - Database username (can be defaulted by project_preflight.sh for Postgres)
#   $4: db_password (string) - Database password (can be empty for Postgres)
#   $5: output_file_base_path (string) - Base path for the output file (e.g., /tmp/my_db_backup)
# Returns:
#   Prints the full path to the created dump file on success (stdout).
#   Returns 0 on success, 1 on failure.
perform_dump() {
    local db_type="$1"
    local db_name="$2"
    local db_user="$3"
    local db_password="$4"
    local output_file_base_path="$5"
    local dump_command=""
    local dump_output_file=""

    _log_db_message INFO "Attempting to dump database '$db_name' (Type: '$db_type')..."

    # Validate mandatory arguments (db_user is still mandatory here, as project_preflight.sh ensures it's set or defaulted)
    if [ -z "$db_type" ] || [ -z "$db_name" ] || [ -z "$db_user" ] || \
       [ -z "$output_file_base_path" ]; then
        _log_db_message ERROR "Missing arguments for perform_dump function. db_user, db_name, db_type, and output_basename_in_temp are mandatory."
        _log_db_message ERROR "Usage: perform_dump <db_type> <db_name> <db_user> <db_password> <output_basename_in_temp>"
        return 1
    fi

    case "$db_type" in
        "mysql")
            dump_output_file="${output_file_base_path}.sql"
            _log_db_message INFO "Using mysqldump for MySQL database, outputting to '$dump_output_file'..."
            # --single-transaction for InnoDB consistency, --quick for large tables, --routines/triggers for stored procedures/triggers
            dump_command="sudo mysqldump --single-transaction --quick --routines --triggers -u \"$db_user\" -p\"$db_password\" \"$db_name\" > \"$dump_output_file\""
            ;;
        "mariadb")
            dump_output_file="${output_file_base_path}.sql"
            # Prioritize mariadb-dump, fall back to mysqldump
            if command -v mariadb-dump &>/dev/null; then
                _log_db_message INFO "Using mariadb-dump for MariaDB database, outputting to '$dump_output_file'..."
                dump_command="sudo mariadb-dump --single-transaction --quick --routines --triggers -u \"$db_user\" -p\"$db_password\" \"$db_name\" > \"$dump_output_file\""
            elif command -v mysqldump &>/dev/null; then
                _log_db_message WARN "mariadb-dump not found. Falling back to mysqldump for MariaDB database, outputting to '$dump_output_file'..."
                dump_command="sudo mysqldump --single-transaction --quick --routines --triggers -u \"$db_user\" -p\"$db_password\" \"$db_name\" > \"$dump_output_file\""
            else
                _log_db_message ERROR "Neither mariadb-dump nor mysqldump found. Cannot backup MariaDB database."
                return 1
            fi
            ;;
        "postgres")
            dump_output_file="${output_file_base_path}.pgcustom.dump" # Using .pgcustom.dump for custom format
            
            local sudo_prefix="sudo" # Default to sudo (run as root)
            local pg_dump_auth_flags="" # Initialize empty. Will be -U if password is provided.

            # If a password is provided, set PGPASSWORD and use -U flag.
            # Otherwise, rely on OS user authentication (peer/ident) by running as that user, without -U.
            if [ -n "$db_password" ]; then
                export PGPASSWORD="$db_password"
                pg_dump_auth_flags="-U \"$db_user\"" # Explicitly pass DB user when password is used
                _log_db_message INFO "PGPASSWORD environment variable set for PostgreSQL authentication. Using -U flag."
            else
                # If no password, attempt to run pg_dump as the specified DB_USER OS user.
                # For peer/ident, pg_dump will typically default to the OS user for DB user.
                _log_db_message INFO "No password provided for PostgreSQL. Attempting to run pg_dump as OS user '$db_user' (for peer/ident authentication)."
                sudo_prefix="sudo -u \"$db_user\""
                # IMPORTANT: No -U flag here, allowing pg_dump to infer DB user from OS user for peer auth.
                # The DB_USER variable is still passed to this function, but not used in the pg_dump command itself
                # when relying on peer authentication.
            fi

            _log_db_message INFO "Using pg_dump for PostgreSQL database, outputting to '$dump_output_file'..."
            # -Fc for custom format (compressed by default), -d for database name
            dump_command="$sudo_prefix pg_dump -Fc $pg_dump_auth_flags -d \"$db_name\" > \"$dump_output_file\""
            ;;
        "mongodb")
            dump_output_file="${output_file_base_path}" # mongodump creates a directory, not a single file
            _log_db_message INFO "Using mongodump for MongoDB database, outputting to directory '$dump_output_file'..."
            # --authenticationDatabase is often needed if user is defined in a different DB (e.g., 'admin')
            # --gzip is for compression, but we handle compression separately for consistency.
            dump_command="sudo mongodump --db=\"$db_name\" --username=\"$db_user\" --password=\"$db_password\" --out=\"$output_file_base_path\""
            # Note: mongodump outputs to a directory. The compression step in actual_backup.sh will need to handle this directory.
            ;;
        *)
            _log_db_message ERROR "Unsupported database type: '$db_type'. Supported: mysql, mariadb, postgres, mongodb."
            return 1
            ;;
    esac

    # Log the command, redacting the password for security
    _log_db_message INFO "Executing dump command: $(echo "$dump_command" | sed "s/-p\"[^\"]*\"/-p\"<redacted>\"/g" | sed "s/--password=\"[^\"]*\"/--password=\"<redacted>\"/g")"
    
    # Execute the dump command
    if eval "$dump_command"; then
        _log_db_message INFO "Database dump for '$db_name' (Type: '$db_type') completed successfully to '$dump_output_file'."
        echo "$dump_output_file" # Output the path to the dump file/directory for the calling script
        return 0
    else
        local dump_exit_code=$?
        _log_db_message ERROR "Database dump for '$db_name' (Type: '$db_type') FAILED (exit code: $dump_exit_code)."
        # Clean up partial dump file/directory if it exists after failure
        if [ -f "$dump_output_file" ] || [ -d "$dump_output_file" ]; then
            _log_db_message WARN "Removing incomplete dump artifact: '$dump_output_file'."
            sudo rm -rf "$dump_output_file" # Use -rf for directories created by mongodump
        fi
        return 1
    fi
}

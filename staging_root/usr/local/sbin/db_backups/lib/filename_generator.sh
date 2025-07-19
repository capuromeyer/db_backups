#!/bin/bash
# -----------------------------------------------------------------------------
# Script: filename_generator.sh
# Purpose: Generates a standard base filename for backups.
#          The caller is responsible for providing the correctly formatted
#          timestamp string representing the actual (previous) backup period.
# Developed by: Alejandro Capuro (Project Lead & Logic Design)
# Implemented by: Jules (AI Assistant, under guidance)
# Copyright: (c) 2025 Alejandro Capuro. All rights reserved.
# File Version: 20250702.170000 # YYYYMMDD.HHMMSS
# Project Version: 1.0.0
#
# Usage:
#   source this script
#   base_name=$(generate_backup_basename "mydb" "2025-07-01-15")
#
# Notes:
#   - Intended to be sourced by other scripts.
# -----------------------------------------------------------------------------

# Function to generate a standard backup base filename.
# The .sql or .sql.zip extension should be added by the caller.
# Arguments:
#   $1: db_name (string) - Name of the database.
#   $2: period_timestamp_string (string) - Pre-calculated and pre-formatted timestamp
#                                          string representing the backup period
#                                          (e.g., "2025-07-01" for daily,
#                                           "2025-07-01-15" for hourly,
#                                           "2025-07-01_W27" for weekly).
# Echos:
#   The generated base filename (e.g., 2025-07-01-15_mydb_backup).
# Returns:
#   0 on success, 1 if arguments are missing.
generate_backup_basename() {
    local db_name="$1"
    local period_timestamp_string="$2"

    if [ -z "$db_name" ]; then
        echo "[FILENAME_GEN_ERROR] Database name not provided to generate_backup_basename." >&2
        return 1
    fi

    if [ -z "$period_timestamp_string" ]; then
        echo "[FILENAME_GEN_ERROR] Period timestamp string not provided for DB '$db_name' to generate_backup_basename." >&2
        return 1
    fi

    echo "${period_timestamp_string}_${db_name}_backup"
    return 0
}

# Example usage (if script is run directly for testing):
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#     echo "Testing filename_generator.sh (generate_backup_basename)..."
#     echo "Test 1 (daily style): $(generate_backup_basename "testdb" "2025-07-01")"
#     echo "Test 2 (hourly style): $(generate_backup_basename "proddb" "2025-07-01-14")"
#     echo "Test 3 (weekly style): $(generate_backup_basename "archive" "2025-06-30_W27")"
#     echo "Test 4 (monthly style): $(generate_backup_basename "summary" "2025-06")"
#
#     echo "Error case (no db_name):"
#     generate_backup_basename "" "2025-07-01"
#     echo "Error case (no period_timestamp_string):"
#     generate_backup_basename "testdb" ""
# fi

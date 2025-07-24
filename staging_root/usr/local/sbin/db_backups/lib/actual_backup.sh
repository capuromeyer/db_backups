#!/bin/bash
# =============================================================================
# Script: actual_backup.sh
# Purpose: Performs the core database backup operations based on the loaded
#          configuration. It handles filename generation, database dumping,
#          compression, and moving the final backup file to its destination.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.155000
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: This script is intended to be sourced by project_list_processor.sh
#        after preflight checks and configuration loading have been completed.
#
# Notes:
# - This script expects all necessary project configuration variables to be
#   loaded in the environment.
# =============================================================================

# Source necessary library scripts
source "/usr/local/sbin/db_backups/lib/filename_generator.sh" || { echo "Error: Could not source /usr/local/sbin/db_backups/lib/filename_generator.sh"; return 1; }
source "/usr/local/sbin/db_backups/lib/db_operations.sh" || { echo "Error: Could not source /usr/local/sbin/db_backups/lib/db_operations.sh"; return 1; }
source "/usr/local/sbin/db_backups/lib/file_operations.sh" || { echo "Error: Could not source /usr/local/sbin/db_backups/lib/file_operations.sh"; return 1; }

# Function: _log_actual_backup_message
# Purpose: Standardized logging helper for messages from this script.
# Arguments: $1 - Log level (INFO, WARN, ERROR)
#            $2 - Message to log
_log_actual_backup_message() {
    local level="$1"
    local message="$2"
    case "$level" in
        INFO)  echo "[ACTUAL_BACKUP] INFO $message" ;;
        WARN)  echo "[ACTUAL_BACKUP] WARN $message" ;;
        ERROR) echo "[ACTUAL_BACKUP] ERROR $message" ;;
        *)     echo "[ACTUAL_BACKUP] UNKNOWN $message" ;;
    esac
}

# Function: perform_actual_backup
# Purpose: Orchestrates the backup process for a single database and a given frequency.
# Arguments:
#   $1: frequency (string) - e.g., "hourly", "daily"
#   $2: db_name_for_backup (string) - The specific database name to backup (e.g., "Testing_DB")
# Returns: The full path to the newly created compressed backup file on success (stdout),
#          or an empty string on failure.
# Expects global variables: TEMP_DIR, TIMESTAMP_STRING, DB_TYPE, DB_USER, DB_PASSWORD,
#                           TTL_*_BACKUP, LOCAL_BACKUP_ROOT, PROJECT_NAME
perform_actual_backup() {
    local frequency="$1"
    local db_name_for_backup="$2"
    local temp_dump_file=""
    local compressed_backup_file_in_temp=""
    local compressed_backup_file_in_local_dest=""
    local exit_status=0 # 0 for success, 1 for failure

    echo ""
    _log_actual_backup_message INFO "Starting actual backup process for database '$db_name_for_backup' with frequency: $frequency"
    #_log_actual_backup_message INFO "Debug: Initial parameters - frequency='$frequency', db_name_for_backup='$db_name_for_backup'"
    #_log_actual_backup_message INFO "Debug: Environment variables (as received by this script): LOCAL_BACKUP_ROOT='$LOCAL_BACKUP_ROOT', TEMP_DIR='$TEMP_DIR', PROJECT_NAME='$PROJECT_NAME', TIMESTAMP_STRING='$TIMESTAMP_STRING', DB_TYPE='$DB_TYPE', DB_USER='$DB_USER'"


    # 1. Generate filename
    echo ""
    echo ""
    _log_actual_backup_message INFO "Step 1: Generating filename..."
    local generated_filename="$(generate_backup_basename "$db_name_for_backup" "$TIMESTAMP_STRING")"
    if [ -z "$generated_filename" ]; then
        _log_actual_backup_message ERROR "Failed to generate backup filename."
        exit_status=1
    fi    
    _log_actual_backup_message INFO "Generated filename: $generated_filename"

    # 2. Perform database dump (ONLY if previous step was successful)
    if [ $exit_status -eq 0 ]; then
        echo ""
        echo ""
        _log_actual_backup_message INFO "Step 2: Performing database dump..."
        # Capture stdout of perform_dump (which should only be the path on success)
        local dump_result=$(perform_dump "$DB_TYPE" "$db_name_for_backup" "$DB_USER" "$DB_PASSWORD" "$TEMP_DIR/${generated_filename}")
        local dump_status=$?

        if [ $dump_status -eq 0 ] && [ -n "$dump_result" ]; then
            temp_dump_file="$dump_result"
            _log_actual_backup_message INFO "Temporary dump file path: $temp_dump_file"
        else
            _log_actual_backup_message ERROR "Database dump failed for '$db_name_for_backup'. (perform_dump exit status: $dump_status)."
            exit_status=1
        fi
    fi

    # 3. Compress dump file (ONLY if previous steps were successful)
    if [ $exit_status -eq 0 ]; then
        echo ""
        echo ""
        _log_actual_backup_message INFO "Step 3: Compressing dump file..."
        # Check if temp_dump_file is valid before attempting compression
        if [ -z "$temp_dump_file" ] || [ ! -f "$temp_dump_file" ] && [ ! -d "$temp_dump_file" ]; then # MongoDB creates a directory
            _log_actual_backup_message ERROR "Input file/directory for compression not found: '$temp_dump_file'."
            exit_status=1
        else
            compressed_backup_file_in_temp="$TEMP_DIR/${generated_filename}.zip" 
            #_log_actual_backup_message INFO "Debug: Parameters for compress_file - Input File='$temp_dump_file', Output Zip File='$compressed_backup_file_in_temp'"
            if ! compress_file "$temp_dump_file" "$compressed_backup_file_in_temp"; then
                _log_actual_backup_message ERROR "File compression failed for '$temp_dump_file'."
                exit_status=1
            else
                _log_actual_backup_message INFO "Compressed backup file path (in temp): $compressed_backup_file_in_temp"
                # Remove the uncompressed dump file/directory after successful compression
                _log_actual_backup_message INFO "Removing temporary dump artifact: $temp_dump_file"
                sudo rm -rf "$temp_dump_file" # Use -rf to handle directories (like from mongodump)
            fi
        fi
    fi

    # Determine the TTL variable name for cleanup
    local ttl_var_name="TTL_$(echo "$frequency" | tr '[:lower:]' '[:upper:]')_BACKUP"
    local retention_minutes="${!ttl_var_name:-0}" # Default to 0 minutes if variable is not set
    #_log_actual_backup_message INFO "Debug: Retention minutes for '$frequency' backups: $retention_minutes"

    # 4. Move compressed file from temp to local final directory (ONLY if previous steps were successful)
    if [ $exit_status -eq 0 ]; then
        echo ""
        echo ""
        _log_actual_backup_message INFO "Step 4: Moving compressed file from temporary to local final directory..."
        local local_dest_dir="$LOCAL_BACKUP_ROOT/$frequency"
        if ! mkdir -p "$local_dest_dir"; then # Use mkdir -p as root in project_preflight if needed
            _log_actual_backup_message ERROR "Failed to create local destination directory: '$local_dest_dir'."
            exit_status=1
        else
            compressed_backup_file_in_local_dest="$local_dest_dir/$(basename "$compressed_backup_file_in_temp")"
            #_log_actual_backup_message INFO "Debug: Moving '$compressed_backup_file_in_temp' to '$local_dest_dir'..."
            if ! mv "$compressed_backup_file_in_temp" "$local_dest_dir/"; then
                _log_actual_backup_message ERROR "Failed to move compressed file to local final storage: '$compressed_backup_file_in_temp' to '$local_dest_dir'."
                exit_status=1
            else
                _log_actual_backup_message INFO "Moved compressed file to local final path: '$compressed_backup_file_in_local_dest'."
                # Clean up old local backups - this should remove files older than TTL
                if ! cleanup_local_backups "$local_dest_dir" "$retention_minutes" "*.zip"; then
                    _log_actual_backup_message WARN "Local cleanup failed for '$local_dest_dir'. Please check the 'cleanup_local_backups' function in 'file_operations.sh'."
                    # Do not set exit_status=1 for cleanup warnings, as the backup itself was successful.
                fi
            fi
        fi
    fi


    # 5. Clean up temporary files (TEMP_DIR)
    # This should always run to ensure temporary directory is cleaned regardless of success/failure
    echo ""
    echo ""
    _log_actual_backup_message INFO "Step 5: Cleaning up temporary files in "$TEMP_DIR"..."

    # Define a reasonable retention for temp files (e.g., 2 hours)
    local temp_file_retention_minutes=120

    if ! cleanup_temp_directory "$TEMP_DIR" "$temp_file_retention_minutes"; then
        _log_actual_backup_message WARN "Temporary directory cleanup failed for '$TEMP_DIR'."
        # Do not set exit_status=1 for cleanup warnings.
    fi

    if [ $exit_status -eq 0 ]; then
        _log_actual_backup_message INFO "Backup process for database '$db_name_for_backup' with frequency '$frequency'."
        echo "Completed Successfully."
        echo "proceeding..."
        echo ""
        # Return the path to the newly created local backup file on stdout
        echo "$compressed_backup_file_in_local_dest"
        return 0
    else
        _log_actual_backup_message ERROR "Backup process for database '$db_name_for_backup' with frequency '$frequency' failed."
        echo "Failed."
	echo ""
        # Return an empty string on stdout to signal failure
        echo ""
        return 1
    fi
}

# The script is designed to be sourced, so the function is called by the calling script.
# No direct execution block needed here.

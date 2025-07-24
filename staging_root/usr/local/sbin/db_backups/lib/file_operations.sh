#!/bin/bash
# =============================================================================
# Script: file_operations.sh
# Purpose: Handles common file operations such as compression, moving backups,
#          and cleaning up old local backup files based on a TTL.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.155600
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: This script is intended to be sourced by other scripts.
#
# Notes:
# - This script is not meant for direct execution.
# - It uses sudo for some operations (mv, rm during cleanup) to handle
#   potential permission restrictions.
# =============================================================================

# Function to compress a file using zip
# Arguments:
#   $1: input_file_path (string) - Full path to the file to compress
#   $2: output_zip_file_path (string) - Full path for the output zip file
# Returns:
#   0 on success, 1 on error.
compress_file() {
    local input_file_path="$1"
    local output_zip_file_path="$2"

    if [ -z "$input_file_path" ] || [ -z "$output_zip_file_path" ]; then
        echo "[FILE_OPS_ERROR] Missing arguments for compress_file function." >&2
        return 1
    fi
    if [ ! -f "$input_file_path" ]; then
        echo "[FILE_OPS_ERROR] Input file '$input_file_path' not found for compression." >&2
        return 1
    fi
    if [ ! -e "$input_file_path" ]; then # Check if file or directory actually exists
        echo "[ERROR] Input path '$input_file_path' does not exist for compression." >&2
        return 1
    fi

    if [ -d "$input_file_path" ]; then
        # Input is a directory.
        local parent_dir
        parent_dir=$(dirname "$input_file_path")
        local dir_to_zip
        dir_to_zip=$(basename "$input_file_path")
        echo "Compressing directory '$dir_to_zip' (from '$parent_dir') into '$output_zip_file_path'..."
        # The `zip -r` command will store paths relative to the current directory.
        # To get a clean archive with dir_to_zip at the root of the zip:
        if (cd "$parent_dir" && sudo zip -q -r "$output_zip_file_path" "$dir_to_zip"); then
            echo "Directory compression successful: '$output_zip_file_path'."
            return 0
        else
            echo "[ERROR] Failed to compress directory '$input_file_path'." >&2
            return 1
        fi
    else
        # Input is a file.
        echo "Compressing file '$input_file_path' to '$output_zip_file_path'..."
        # Using -j to junk paths (store only the filename inside the zip).
        if sudo zip -q -j "$output_zip_file_path" "$input_file_path"; then
            echo "File compression successful: '$output_zip_file_path'."
            return 0
        else
            echo "[ERROR] Failed to compress file '$input_file_path'." >&2
            return 1
        fi
    fi
}

# Function to move a backup file to its destination directory
# Arguments:
#   $1: source_file_path (string) - Full path of the file to move
#   $2: destination_dir_path (string) - Full path of the directory to move into
# Returns:
#   0 on success, 1 on error.
move_backup() {
    local source_file_path="$1"
    local destination_dir_path="$2"

    if [ -z "$source_file_path" ] || [ -z "$destination_dir_path" ]; then
        echo "[FILE_OPS_ERROR] Missing arguments for move_backup function." >&2
        return 1
    fi
    if [ ! -f "$source_file_path" ]; then
        echo "[FILE_OPS_ERROR] Source file '$source_file_path' not found for move." >&2
        return 1
    fi
    if [ ! -d "$destination_dir_path" ]; then
        # Attempt to create the destination directory if it doesn't exist
        echo "[FILE_OPS_WARN] Destination directory '$destination_dir_path' not found. Attempting to create..." >&2
        if sudo mkdir -p "$destination_dir_path"; then
            echo "[FILE_OPS_INFO] Created destination directory '$destination_dir_path'."
        else
            echo "[FILE_OPS_ERROR] Failed to create destination directory '$destination_dir_path' for move." >&2
            return 1
        fi
    fi

    echo "[FILE_OPS_INFO] Moving '$source_file_path' to '$destination_dir_path'..."
    if sudo mv "$source_file_path" "$destination_dir_path/"; then
        echo "[FILE_OPS_INFO] File moved successfully to '$destination_dir_path'."
        return 0
    else
        echo "[FILE_OPS_ERROR] Failed to move '$source_file_path' to '$destination_dir_path'." >&2
        return 1
    fi
}



# Function to clean up old local backup files
# Arguments:
#   $1: backup_dir_path (string) - Directory to clean up
#   $2: ttl_minutes (integer) - Time to live in minutes. Files older than this will be removed.
#   $3: file_pattern (string, optional) - Pattern for files to find (e.g., "*.zip"). Default: "*.zip"
# Returns:
#   0 on success (even if no files found/removed), 1 on major error (like find/xargs failing).
cleanup_local_backups() {
    local backup_dir_path="$1"
    local ttl_minutes="$2"
    local file_pattern="${3:-*.zip}"

    if [ -z "$backup_dir_path" ] || [ -z "$ttl_minutes" ]; then
        echo "[FILE_OPS_ERROR] Missing arguments for cleanup_local_backups function. Usage: cleanup_local_backups <directory> <ttl_minutes> [file_pattern]" >&2
        return 1
    fi

    if [ ! -d "$backup_dir_path" ]; then
        echo "[FILE_OPS_WARN] Backup directory '$backup_dir_path' not found for cleanup. Skipping." >&2
        return 0
    fi

    # Ensure ttl_minutes is a non-negative integer. If 0 or less, skip cleanup.
    if ! [[ "$ttl_minutes" =~ ^[0-9]+$ ]]; then
        echo "[FILE_OPS_ERROR] Invalid TTL '$ttl_minutes' for '$backup_dir_path'. TTL must be a non-negative integer. Skipping cleanup." >&2
        return 1
    fi

    if [ "$ttl_minutes" -le 0 ]; then
        echo "[FILE_OPS_INFO] TTL '$ttl_minutes' is set to 0 or less for '$backup_dir_path'. No retention policy applied; skipping automatic cleanup."
        return 0
    fi

    local human_readable_ttl
    if (( ttl_minutes < 60 )); then
        human_readable_ttl="${ttl_minutes} minute(s)"
    elif (( ttl_minutes < 1440 )); then
        human_readable_ttl="$((ttl_minutes / 60)) hour(s)"
    else
        human_readable_ttl="$((ttl_minutes / 1440)) day(s)"
    fi

    echo "[FILE_OPS_INFO] Cleaning up files matching '$file_pattern' older than $ttl_minutes minutes ($human_readable_ttl) in '$backup_dir_path'..."

    local files_found_for_deletion=0

    # First, list files to be removed for logging/debugging
    local files_to_delete_list
    files_to_delete_list=$(sudo find "$backup_dir_path" -maxdepth 1 -name "$file_pattern" -type f -mmin "+$ttl_minutes" -print)

    if [ -n "$files_to_delete_list" ]; then
        echo "[FILE_OPS_INFO] The following old files will be removed from '$backup_dir_path':"
        echo "$files_to_delete_list" | sed 's|^|    - |' # Indent for readability
        files_found_for_deletion=$(echo "$files_to_delete_list" | wc -l)
    else
        echo "[FILE_OPS_INFO] No files found older than TTL in '$backup_dir_path' matching '$file_pattern'."
    fi

    if [ "$files_found_for_deletion" -gt 0 ]; then
        echo "[FILE_OPS_INFO] Attempting to remove $files_found_for_deletion old backup(s)..."
        # Use -print0 and xargs -0 to correctly handle filenames with spaces or special characters.
        if sudo find "$backup_dir_path" -maxdepth 1 -name "$file_pattern" -type f -mmin "+$ttl_minutes" -print0 | xargs -0 sudo rm -f; then
            echo "[FILE_OPS_INFO] Old backups cleanup process complete for '$backup_dir_path'."
        else
            echo "[FILE_OPS_ERROR] Failed to delete some old backups in '$backup_dir_path'. Review permissions or disk space." >&2
            return 1 # Indicate a failure in cleanup
        fi
    fi

    return 0
}




# Function to clean up old local backup files
# Arguments:
#   $1: backup_dir_path (string) - Directory to clean up
#   $2: ttl_minutes (integer) - Time to live in minutes. Files older than this will be removed.
#   $3: file_pattern (string, optional) - Pattern for files to find (e.g., "*.zip"). Default: "*.zip"
# Returns:
#   0 on success (even if no files found/removed), 1 on major error (like cd failing).
cleanup_local_backups_legacy() {
    local backup_dir_path="$1"
    local ttl_minutes="$2"
    local file_pattern="${3:-*.zip}"

    if [ -z "$backup_dir_path" ] || [ -z "$ttl_minutes" ]; then
        echo "[FILE_OPS_ERROR] Missing arguments for cleanup_local_backups function." >&2
        return 1
    fi
    if [ ! -d "$backup_dir_path" ]; then
        echo "[FILE_OPS_WARN] Backup directory '$backup_dir_path' not found for cleanup. Skipping." >&2
        return 0
    fi
    if ! [[ "$ttl_minutes" =~ ^[0-9]+$ ]] || [ "$ttl_minutes" -le 0 ]; then
        echo "[FILE_OPS_INFO] TTL '$ttl_minutes' is not a positive integer for '$backup_dir_path'. Skipping cleanup."
        return 0
    fi

    local human_readable_ttl
    if (( ttl_minutes < 60 )); then
        human_readable_ttl="${ttl_minutes} minute(s)"
    elif (( ttl_minutes < 1440 )); then
        human_readable_ttl="$((ttl_minutes / 60)) hour(s)"
    else
        human_readable_ttl="$((ttl_minutes / 1440)) day(s)"
    fi

    echo "[FILE_OPS_INFO] Cleaning up files matching '$file_pattern' older than $ttl_minutes minutes ($human_readable_ttl) in '$backup_dir_path'..."

    local current_dir
    current_dir=$(pwd)

    cd "$backup_dir_path" || {
        echo "[FILE_OPS_ERROR] Could not cd to '$backup_dir_path' for cleanup. Skipping." >&2
        return 1
    }

    echo "[FILE_OPS_INFO] The following old files will be removed from '$backup_dir_path':"
    sudo find . -maxdepth 1 -name "$file_pattern" -type f -mmin "+$ttl_minutes" -print
    if sudo find . -maxdepth 1 -name "$file_pattern" -type f -mmin "+$ttl_minutes" -exec sudo rm -f {} \; ; then
        echo "[FILE_OPS_INFO] Old backups cleanup process complete for '$backup_dir_path'."
    else
        echo "[FILE_OPS_WARN] 'find ... -exec rm' command may have encountered an issue in '$backup_dir_path'. Some files might not have been deleted." >&2
    fi

    cd "$current_dir"
    return 0
}

# Function to clean up the general temporary directory
# Arguments:
#   $1: temp_dir_path (string) - The temporary directory to clean
#   $2: max_age_minutes (integer) - Items older than this many minutes will be removed
# Returns:
#   0 on success or if no items to clean, 1 on critical error (e.g., invalid args)
cleanup_temp_directory() {
    local temp_dir_path="$1"
    local max_age_minutes="$2"

    if [ -z "$temp_dir_path" ] || [ ! -d "$temp_dir_path" ]; then
        echo "[ERROR] Temporary directory '$temp_dir_path' invalid or not found for cleanup sweep." >&2
        return 1
    fi
    if ! [[ "$max_age_minutes" =~ ^[0-9]+$ ]] || [ "$max_age_minutes" -lt 5 ]; then # Minimum 5 minutes to be somewhat safe
        echo "[ERROR] Invalid max_age_minutes '$max_age_minutes' for temp dir cleanup sweep. Must be at least 5." >&2
        return 1
    fi

    echo ""
    echo "Performing general cleanup of temporary directory: '$temp_dir_path'"
    echo "Removing items older than $max_age_minutes minutes..."

    # List items to be deleted first (for logging/dry-run feel, without actually deleting yet here)
    # This is purely for output, actual deletion is next.
    local items_to_remove
    items_to_remove=$(sudo find "$temp_dir_path" -mindepth 1 -mmin "+$max_age_minutes" -print)

    if [ -n "$items_to_remove" ]; then
        echo "The following temporary items will be targeted for removal (if older than $max_age_minutes minutes):"
        echo "$items_to_remove" # This will list each file/dir on a new line
    else
        echo "No items found older than $max_age_minutes minutes in '$temp_dir_path'."
    fi

    # Actual deletion command
    if sudo find "$temp_dir_path" -mindepth 1 -mmin "+$max_age_minutes" -exec rm -rf {} \; ; then
         echo "Temporary directory cleanup sweep finished for items older than $max_age_minutes minutes."
    else
         echo "[WARNING] Temporary directory cleanup sweep command encountered issues for '$temp_dir_path'. Some old items might remain." >&2
         # Not returning 1 here as this is best-effort for general sweep.
    fi
    echo ""
    return 0
}

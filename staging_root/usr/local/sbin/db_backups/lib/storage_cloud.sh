#!/bin/bash
# =============================================================================
# Script: storage_cloud.sh
# Purpose: Provides functions for synchronizing local backup files to cloud
#          storage (AWS S3, Cloudflare R2) and performing cloud-based cleanup.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.160100
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: This script is intended to be sourced by other scripts (e.g.,
#        project_list_processor.sh).
#
# Notes:
# - This script is not meant for direct execution.
# - It expects several global variables (e.g., CLOUD_STORAGE_PROVIDER,
#   S3_BUCKET_NAME) to be set by the calling environment.
# =============================================================================

# --- Logging Helper Function (re-defined for this script's context) ---
# Function: log_message
# Purpose: Standardized logging helper for messages from this script.
# Arguments: $1 - Log level (INFO, WARN, ERROR)
#            $2 - Message to log
log_message() {
    local level="$1"
    local message="$2"
    # Direct all messages to standard output
    case "$level" in
        INFO)    echo "[STORAGE_CLOUD] INFO $message" ;;
        WARN)    echo "[STORAGE_CLOUD] WARN $message" ;;
        ERROR)   echo "[STORAGE_CLOUD] ERROR $message" ;;
        *)       echo "[STORAGE_CLOUD] UNKNOWN $message" ;; # Fallback for unknown levels
    esac
}

# Function: sync_to_cloud_s3 (Retaining old name for compatibility with project_list_processor.sh)
# Purpose: Synchronizes a local directory to a specified cloud storage path using s3cmd.
#          This performs a full sync (add, update, delete) if BACKUP_TYPE is "both".
# Arguments:
#   $1: local_source_dir (string) - The local directory to sync from.
#   $2: cloud_target_path (string) - The full cloud path (e.g., s3://mybucket/backups/hourly/)
# Returns: 0 on success, 1 on failure.
sync_to_cloud_s3() {
    local local_source_dir="$1"
    local cloud_target_path="$2"
    local sync_command=""
    local sync_output=""

    echo ""
    log_message INFO "Attempting to synchronize local directory via s3cmd."
    echo "Local Directory: '$local_source_dir' | Cloud path: '$cloud_target_path' | Provider: '$CLOUD_STORAGE_PROVIDER'"
    echo ""

    # Ensure AWS_CONFIG_FILE is set for root if it's not already (needed for cleanup_cloud_s3 later)
    export AWS_CONFIG_FILE="/root/.aws/config"

    # Ensure local_source_dir ends with a slash for s3cmd sync to sync contents
    if [[ "${local_source_dir: -1}" != "/" ]]; then
        local_source_dir="${local_source_dir}/"
        log_message INFO "Appended trailing slash to local_source_dir: '$local_source_dir'."
    fi
    # Ensure cloud_target_path ends with a slash for s3cmd sync
    if [[ "${cloud_target_path: -1}" != "/" ]]; then
        cloud_target_path="${cloud_target_path}/"
        log_message INFO "Appended trailing slash to cloud_target_path: '$cloud_target_path'."
    fi


    case "$CLOUD_STORAGE_PROVIDER" in
        "s3")
            sync_command="s3cmd sync --skip-existing --delete-removed \"$local_source_dir\" \"$cloud_target_path\""
            ;;
        "r2")
            if [ -z "$R2_S3CMD_CONFIG_PATH" ]; then
                log_message ERROR "R2_S3CMD_CONFIG_PATH is not set. Cannot perform R2 sync via s3cmd."
                return 1
            fi
            sync_command="s3cmd -c \"$R2_S3CMD_CONFIG_PATH\" sync --skip-existing --delete-removed \"$local_source_dir\" \"$cloud_target_path\""
            ;;
        *)
            log_message ERROR "Unsupported cloud storage provider for sync: '$CLOUD_STORAGE_PROVIDER'."
            return 1
            ;;
    esac

    log_message INFO "Executing s3cmd sync command: $sync_command"
    if ! sync_output=$(eval "$sync_command" 2>&1); then
        log_message ERROR "Cloud synchronization failed for '$local_source_dir' to '$cloud_target_path'."
        log_message ERROR "s3cmd output: $sync_output"
        return 1
    else
	echo ""
        echo "s3cmd output: $sync_output"
	echo "---------------------------"
        log_message INFO "Cloud synchronization completed successfully."
        echo "---------------------------"
	echo ""
        return 0
    fi
}

# Function: s3_upload_only_sync (Retaining old name for compatibility with project_list_processor.sh)
# Purpose: Uploads new or modified files from a local directory to a specified cloud storage path using s3cmd.
#          This performs an 'upload-only' sync, suitable when BACKUP_TYPE is "cloud" (no local copy retention).
# Arguments:
#   $1: local_source_dir (string) - The local directory to upload from.
#   $2: cloud_target_path (string) - The full cloud path (e.g., s3://mybucket/backups/hourly/)
# Returns: 0 on success, 1 on failure.
s3_upload_only_sync() {
    local local_source_dir="$1"
    local cloud_target_path="$2"
    local upload_command=""
    local upload_output=""

    echo ""
    log_message INFO "Attempting to upload new/modified files via s3cmd --no-delete."
    echo "Local Directory: '$local_source_dir' | Cloud Path '$cloud_target_path' | Provider: '$CLOUD_STORAGE_PROVIDER' "
    echo ""

    # Ensure AWS_CONFIG_FILE is set for root if it's not already (needed for cleanup_cloud_s3 later)
    export AWS_CONFIG_FILE="/root/.aws/config"

    # Ensure local_source_dir ends with a slash for s3cmd sync to sync contents
    if [[ "${local_source_dir: -1}" != "/" ]]; then
        local_source_dir="${local_source_dir}/"
        log_message INFO "Appended trailing slash to local_source_dir: '$local_source_dir'."
    fi
    # Ensure cloud_target_path ends with a slash for s3cmd sync
    if [[ "${cloud_target_path: -1}" != "/" ]]; then
        cloud_target_path="${cloud_target_path}/"
        log_message INFO "Appended trailing slash to cloud_target_path: '$cloud_target_path'."
    fi

    case "$CLOUD_STORAGE_PROVIDER" in
        "s3")
            # Using --exclude "*" --include "*.zip" to only consider zip files
            upload_command="s3cmd sync --no-delete --skip-existing --exclude \"*\" --include \"*.zip\" \"$local_source_dir\" \"$cloud_target_path\""
            ;;
        "r2")
            if [ -z "$R2_S3CMD_CONFIG_PATH" ]; then
                log_message ERROR "R2_S3CMD_CONFIG_PATH is not set. Cannot perform R2 upload via s3cmd."
                return 1
            fi
            upload_command="s3cmd -c \"$R2_S3CMD_CONFIG_PATH\" sync --no-delete --skip-existing --exclude \"*\" --include \"*.zip\" \"$local_source_dir\" \"$cloud_target_path\""
            ;;
        *)
            log_message ERROR "Unsupported cloud storage provider for upload: '$CLOUD_STORAGE_PROVIDER'."
            return 1
            ;;
    esac

    log_message INFO "Executing s3cmd upload command: $upload_command"
    if ! upload_output=$(eval "$upload_command" 2>&1); then
        log_message ERROR "Cloud upload failed for '$local_source_dir' to '$cloud_target_path'."
        log_message ERROR "s3cmd output: $upload_output"
        return 1
    else
        log_message INFO "Cloud upload completed successfully."
        log_message INFO "s3cmd output: $upload_output"
        return 0
    fi
}

# Function: cleanup_cloud_s3 (Retaining old name for compatibility with project_list_processor.sh)
# Purpose: Cleans up old backup files in cloud storage based on retention policy.
# Arguments:
#   $1: cloud_path (string) - The full cloud path where backups are stored (e.g., s3://mybucket/backups/hourly/)
#   $2: retention_minutes (integer) - The age in minutes after which files should be deleted.
#   $3: file_pattern (string) - The pattern of files to clean (e.g., "*.zip").
# Returns: 0 on success, 1 on failure.
cleanup_cloud_s3() {
    local cloud_path="$1"
    local retention_minutes="$2"
    local file_extension="${3##*.}" # Extract 'zip' from '*.zip'
    local cleanup_output=""
    local list_command=""
    local delete_command_base=""
    local bucket_name="$(echo "$cloud_path" | sed 's/s3:\/\///' | cut -d'/' -f1)"
    local prefix_path="$(echo "$cloud_path" | sed 's/s3:\/\/[^/]*\///')"

    echo ""
    log_message INFO "Starting cloud cleanup using provider '$CLOUD_STORAGE_PROVIDER'."
    echo "Path '$cloud_path' | Retention : '$retention_minutes' minutes | Pattern '*.${file_extension}' "
    echo ""

    # Ensure AWS_CONFIG_FILE is set for root if it's not already
    export AWS_CONFIG_FILE="/root/.aws/config"

    # Calculate the cutoff timestamp (files older than this should be deleted)
    local cutoff_timestamp_seconds=$(date -d "$retention_minutes minutes ago" +%s)

    case "$CLOUD_STORAGE_PROVIDER" in
        "s3")
            # List objects, fetching Key and LastModified, and filter by prefix and extension
            list_command="aws s3api list-objects-v2 --bucket \"$bucket_name\" --prefix \"$prefix_path\" --query 'Contents[?ends_with(Key, \`.${file_extension}\`)].{Key: Key, LastModified: LastModified}' --output text"
            delete_command_base="aws s3api delete-object --bucket \"$bucket_name\""
            ;;
        "r2")
            if [ -z "$R2_AWS_PROFILE_NAME" ]; then
                log_message ERROR "R2_AWS_PROFILE_NAME is not set. Cannot perform R2 cleanup."
                return 1
            fi
            # List objects for R2, fetching Key and LastModified, and filter by prefix and extension
            list_command="aws s3api list-objects-v2 --bucket \"$bucket_name\" --prefix \"$prefix_path\" --profile \"$R2_AWS_PROFILE_NAME\" --query 'Contents[?ends_with(Key, \`.${file_extension}\`)].{Key: Key, LastModified: LastModified}' --output text"
            delete_command_base="aws s3api delete-object --bucket \"$bucket_name\" --profile \"$R2_AWS_PROFILE_NAME\""
            ;;
        *)
            log_message ERROR "Unsupported cloud storage provider for cleanup: '$CLOUD_STORAGE_PROVIDER'."
            return 1
            ;;
    esac

    log_message INFO "Executing list command for cleanup: $(echo "$list_command" | head -n 1)" # Log only the first line for brevity
    local object_list_raw
    if ! object_list_raw=$(eval "$list_command" 2>&1); then
        log_message WARN "Failed to list objects for cleanup in '$cloud_path'. Cloud provider output: $object_list_raw"
        return 1
    fi

    local files_to_delete_keys=() # Array to store keys of files to be deleted

    # Process each line from the object list
    # Each line is expected to be "Key\tLastModified"
    while IFS=$'\t' read -r key last_modified; do
        if [ -z "$key" ]; then continue; fi # Skip empty lines

        # Convert LastModified timestamp to epoch seconds
        # AWS CLI returns LastModified in ISO 8601 format (e.g., 2025-07-17T14:30:00.000Z)
        # date -d can parse this.
        local file_timestamp_seconds=$(date -d "$last_modified" +%s 2>/dev/null)

        if [ -z "$file_timestamp_seconds" ]; then
            log_message WARN "Could not parse timestamp for key: '$key' (LastModified: '$last_modified'). Skipping."
            continue
        fi

        # Compare file's timestamp with cutoff timestamp
        if (( file_timestamp_seconds < cutoff_timestamp_seconds )); then
            log_message INFO "Identified old file for deletion: '$key' (LastModified: $last_modified, Epoch: $file_timestamp_seconds) is older than cutoff ($cutoff_timestamp_seconds)."
            files_to_delete_keys+=("$key")
        fi
    done <<< "$object_list_raw"

    if [ ${#files_to_delete_keys[@]} -eq 0 ]; then
        log_message INFO "No old files found for cleanup in '$cloud_path' matching retention policy."
        return 0
    fi

    log_message INFO "Found ${#files_to_delete_keys[@]} old files to delete."

    # Iterate through each file found and delete it
    local overall_delete_success=0 # 0 for success, 1 if any deletion fails
    for file_key in "${files_to_delete_keys[@]}"; do
        local delete_command="$delete_command_base --key \"$file_key\""
        log_message INFO "Executing delete command: $delete_command"
        if eval "$delete_command" &>/dev/null; then
            log_message INFO "Successfully deleted: $file_key"
        else
            log_message WARN "Failed to delete: $file_key. Cloud provider output: $(eval "$delete_command" 2>&1)"
            overall_delete_success=1 # Mark overall cleanup as failed if any deletion fails
        fi
    done

    if [ "$overall_delete_success" -eq 0 ]; then
        log_message INFO "Cloud cleanup completed successfully for '$cloud_path'."
        return 0
    else
        log_message WARN "Cloud cleanup completed with some failures for '$cloud_path'."
        return 1
    fi
}

#!/bin/bash
# -----------------------------------------------------------------------------
# Script: project_list_processor.sh
# Purpose: Reads a list of project paths from an input file, and for each path,
#          executes user-defined logic for a SPECIFIC backup frequency.
# Developed by: Jules (AI Assistant)
# Copyright: (c) 2025 Alejandro Capuro. All rights reserved.
# File Version: 20250721.150000 # Updated version after fixing cloud sync logic
# Project Version: 1.0.0
#
# Usage: ./project_list_processor.sh <path_to_list_of_projects.txt> <frequency>
#   <frequency> can be: minutely, hourly, daily, weekly, monthly, yearly
#
# Notes:
#   - This script now receives an ALREADY FILTERED list of project paths from global-runner.sh.
#   - It no longer performs frequency-based filtering itself.
#   - It explicitly sources 'project_preflight.sh' once at the beginning.
#   - Collects and reports status for each individual database backup.
# -----------------------------------------------------------------------------

# --- Global Configuration & Variables ---
# Determine the directory of the current script.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Define the path to the external script that contains the functions to be called.
# This assumes project_list_processor.sh is in '/usr/local/sbin/db_backups/lib/'
# and project_preflight.sh is in '/usr/local/sbin/db_backups/'.
PREFLIGHT_SCRIPT_PATH="$(dirname "$SCRIPT_DIR")/project_preflight.sh"
ACTUAL_BACKUP_PATH="/usr/local/sbin/db_backups/lib/actual_backup.sh"
FILENAME_GENERATOR_PATH="/usr/local/sbin/db_backups/lib/filename_generator.sh"
STORAGE_CLOUD_PATH="/usr/local/sbin/db_backups/lib/storage_cloud.sh"
FILE_OPERATIONS_PATH="/usr/local/sbin/db_backups/lib/file_operations.sh"

# --- Logging Helper Function ---

# Function: log_message_plp
# Purpose: Standardized logging helper for messages from this script.
#          All messages are directed to standard output (stdout).
# Arguments: $1 - Log level (INFO, WARN, ERROR)
#            $2 - Message to log
log_message_plp() {
    local level="$1"
    local message="$2"
    # Direct all messages to standard output
    case "$level" in
        INFO)    echo "[PROJECT_PROCESSOR] INFO $message" ;;
        WARN)    echo "[PROJECT_PROCESSOR] WARN $message" ;;
        ERROR)   echo "[PROJECT_PROCESSOR] ERROR $message" ;;
        *)       echo "[PROJECT_PROCESSOR] UNKNOWN $message" ;; # Fallback for unknown levels
    esac
}

# --- Main Processing Function ---

# Function: process_project_list
# Purpose: Takes a file path to a list of project entries, reads each path,
#          generates an initial report on the listed files, and then executes
#          user-defined logic for each project for a specified frequency.
# Arguments:
#   $1 - Path to the list file containing project paths (already filtered by frequency).
#   $2 - The specific backup frequency to run (e.g., "hourly", "daily").
# Returns: 0 on overall success (all projects processed successfully or no projects),
#          1 if any fundamental error occurred (e.g., input file missing)
#          or if one or more project executions failed.
process_project_list() {
    local list_file_path="$1"
    local target_frequency="$2" # Capture the specified frequency
    local total_processed_projects=0
    local successful_projects=0
    local failed_projects=0
    local project_paths_array=() # Array to store valid project paths from the input file
    local processed_project_names=()     # Array to store basenames of processed projects
    local processed_project_statuses=() # Array to store status (PASSED/FAILED/SKIPPED) of processed projects
    local -a DATABASE_BACKUP_SUMMARY=() # Array to store "PROJECT_NAME|DB_NAME|STATUS|FILE_PATH" for final report

    # Define allowed frequencies for validation (still needed for argument validation)
    local allowed_frequencies=("minutely" "hourly" "daily" "weekly" "monthly" "yearly")
    local is_valid_frequency=0
    for freq_check in "${allowed_frequencies[@]}"; do
        if [[ "$target_frequency" == "$freq_check" ]]; then
            is_valid_frequency=1
            break
        fi
    done

    # 1. Validate input file path argument
    if [ -z "$list_file_path" ]; then
        log_message_plp ERROR "No input file path provided. Please specify the path to the list of projects. Example: ./project_list_processor.sh /path/to/your/project_list.txt <frequency>"
        return 1
    fi

    # 2. Validate target frequency argument
    if [ -z "$target_frequency" ]; then
        log_message_plp ERROR "No backup frequency provided. Please specify one (e.g., 'hourly'). Allowed frequencies: ${allowed_frequencies[*]}."
        return 1
    elif [ "$is_valid_frequency" -eq 0 ]; then
        log_message_plp ERROR "Invalid backup frequency provided: '$target_frequency'. Allowed frequencies: ${allowed_frequencies[*]}."
        return 1
    fi

    # 3. Validate input file existence
    if [ ! -f "$list_file_path" ]; then
        log_message_plp ERROR "Input project list file not found: '$list_file_path'. Please ensure the file exists and the path is correct."
        return 1
    fi

    # --- Read all valid project paths into an array (READ FILE ONCE) ---
    while IFS= read -r line || [[ -n "$line" ]]; do
        local trimmed_line=$(echo "$line" | xargs) # Use xargs to trim whitespace
        if [[ -z "$trimmed_line" || "$trimmed_line" =~ ^# ]]; then
            continue # Skip empty lines and comments
        fi
        project_paths_array+=("$trimmed_line") # Add valid path to array
    done < "$list_file_path"

    # --- Initial Projects to be Processed Report (Format Only - No Validation) ---
    local report_total_listed_files=${#project_paths_array[@]}

    echo "----------------------------------------"
    echo ""
    echo "List of Projects to be Processed for Frequency: '$target_frequency'"
    echo ""
    echo "----------------------------------------"
    printf "%-50s | %s\n" "Project Name" "Status"
    echo "----------------------------------------"

    # Iterate over the array for the report
    if [ "$report_total_listed_files" -eq 0 ]; then
        printf "%-50s | %s\n" "No projects found" "N/A"
    else
        for report_file_path in "${project_paths_array[@]}"; do
            printf "%-50s | %s\n" "$(basename "$report_file_path")" "Listed"
        done
    fi

    echo "----------------------------------------"
    echo "Total: $report_total_listed_files, Listed: $report_total_listed_files"
    echo "----------------------------------------"
    echo "" # Add a blank line after the report

    # --- End Initial Report ---

    # --- Source necessary scripts once at the beginning ---
    log_message_plp INFO "Loading project audit protocol from:"
    echo "'$PREFLIGHT_SCRIPT_PATH'..."
    if [ ! -f "$PREFLIGHT_SCRIPT_PATH" ]; then
        log_message_plp ERROR "Script not found at '$PREFLIGHT_SCRIPT_PATH'. Please verify the script exists at the specified path."
        return 1
    fi
    # shellcheck source=/dev/null
    source "$PREFLIGHT_SCRIPT_PATH" || {
        log_message_plp ERROR "Failed to source script file from '$PREFLIGHT_SCRIPT_PATH'. Please check the script for syntax errors or permission issues."
        return 1
    }
    echo ""
    echo "Project audit logic script loaded successfully..."
    echo ""

    echo "Loading backup mechanic script from:"
    echo "'$ACTUAL_BACKUP_PATH'..."
    if [ ! -f "$ACTUAL_BACKUP_PATH" ]; then
        log_message_plp ERROR "Script not found at '$ACTUAL_BACKUP_PATH'. Please verify the script exists at the specified path."
        return 1
    fi
    source "$ACTUAL_BACKUP_PATH" || {
        log_message_plp ERROR "Failed to source script file from '$ACTUAL_BACKUP_PATH'. Please check the script for syntax errors or permission issues."
        return 1
    }
    echo "Backup mechanic script loaded successfully..."
    echo ""

    echo "Loading filename generator script from:"
    echo "'$FILENAME_GENERATOR_PATH'..."
    if [ ! -f "$FILENAME_GENERATOR_PATH" ]; then
        log_message_plp ERROR "Script not found at '$FILENAME_GENERATOR_PATH'. Please verify the script exists at the specified path."
        return 1
    fi
    source "$FILENAME_GENERATOR_PATH" || {
        log_message_plp ERROR "Failed to source script file from '$FILENAME_GENERATOR_PATH'. Please check the script for syntax errors or permission issues."
        return 1
    }
    echo "Filename generator script loaded successfully..."
    echo ""

    echo "Loading cloud storage operations script from:"
    echo "'$STORAGE_CLOUD_PATH'..."
    if [ ! -f "$STORAGE_CLOUD_PATH" ]; then
        log_message_plp ERROR "Script not found at '$STORAGE_CLOUD_PATH'. Please verify the script exists at the specified path."
        return 1
    fi
    source "$STORAGE_CLOUD_PATH" || {
        log_message_plp ERROR "Failed to source script file from '$STORAGE_CLOUD_PATH'. Please check the script for syntax errors or permission issues."
        return 1
    }
    echo "Cloud storage operations script loaded successfully..."
    echo ""

    echo "Loading file operations script from:"
    echo "'$FILE_OPERATIONS_PATH'..."
    if [ ! -f "$FILE_OPERATIONS_PATH" ]; then
        log_message_plp ERROR "Script not found at '$FILE_OPERATIONS_PATH'. Please verify the script exists at the specified path."
        return 1
    fi
    source "$FILE_OPERATIONS_PATH" || {
        log_message_plp ERROR "Failed to source script file from '$FILE_OPERATIONS_PATH'. Please check the script for syntax errors or permission issues."
        return 1
    }
    echo "File operations script loaded successfully..."
    echo ""
    log_message_plp INFO "All loads complete proceeding..."
    echo ""

    # --- End Sourcing ---


    log_message_plp INFO "Starting processing each project for frequency: '$target_frequency'"
    echo "Project List File: '$(basename "$list_file_path")'"
    echo ""
    echo "----------------------------------------------------------------"
    # 4. Loop through the array for main processing
    if [ "$report_total_listed_files" -eq 0 ]; then
        log_message_plp INFO "No projects to process from the list."
    else
        for current_project_path in "${project_paths_array[@]}"; do
            total_processed_projects=$((total_processed_projects + 1))
            local project_name="$(basename "$current_project_path")"
            echo ""
            echo "$project_name"
            echo ""
            echo "Initiating Project Run for frequency '$target_frequency'..."
            echo ""


            # --- USER MODIFICATION POINT ---
            # This is the section where YOU, the user, will insert your custom logic.
            # The variable 'current_project_path' holds the full path read from the input file.
            #
            # Example: Call the run_all_project_preflight_checks function from the sourced script.
            # This function is assumed to accept the project configuration path as its argument.
            #
            # IMPORTANT: The exit status of the last command in this block will determine
            #            if the 'Logic execution PASSED' or 'FAILED' message is logged.
            #            Ensure your custom logic sets an appropriate exit status.
            # -------------------------------

            # Call the run_all_project_preflight_checks function
            # Note: project_preflight.sh no longer performs frequency filtering itself.
            # It only validates the project config.
            run_all_project_preflight_checks "$current_project_path"
            local project_preflight_status=$?

            if [ "$project_preflight_status" -eq 0 ]; then
                log_message_plp INFO "Project preflight for '$project_name' PASSED."
                # Generate TIMESTAMP_STRING for the *previous* period, based on frequency for readability.
                local current_run_timestamp_string
                case "$target_frequency" in
                    "minutely") current_run_timestamp_string=$(date -d "1 minute ago" +"%Y-%m-%d-%H%M") ;;
                    "hourly")   current_run_timestamp_string=$(date -d "1 hour ago" +"%Y-%m-%d_H%H") ;;
                    "daily")    current_run_timestamp_string=$(date -d "1 day ago" +"%Y-%m-%d") ;;
                    "weekly")   current_run_timestamp_string=$(date -d "1 week ago" +"%Y-%m-%d_W%V") ;; # ISO week number
                    "monthly")  current_run_timestamp_string=$(date -d "1 month ago" +"%Y-%m") ;;
                    "yearly")   current_run_timestamp_string=$(date -d "1 year ago" +"%Y") ;;
                    *)          current_run_timestamp_string=$(date +"%Y-%m-%d-%H%M%S") ;; # Fallback (should not happen with valid frequencies)
                esac
                TIMESTAMP_STRING="$current_run_timestamp_string" # Set the global variable
                log_message_plp INFO "Generated TIMESTAMP_STRING for '$project_name', frequency '$target_frequency': '$TIMESTAMP_STRING' (reflects previous period)."

                # DBS_TO_BACKUP is a global array set by project_preflight.sh after sourcing the config.
                # Check if DBS_TO_BACKUP is empty.
                if [ -z "${DBS_TO_BACKUP[*]}" ]; then
                    log_message_plp WARN "No databases specified in DBS_TO_BACKUP for project '$project_name'. Skipping backup for this project and frequency."
                    processed_project_statuses+=("SKIPPED (No DBs)")
                    continue # Skip to the next project
                fi

                local project_has_db_backup_failures=0 # Flag for this project's database backups

                # Iterate through each database specified in DBS_TO_BACKUP
                for db_name_to_backup in "${DBS_TO_BACKUP[@]}"; do
                    echo ""
                    log_message_plp INFO "Attempting backup for project '$project_name', database: '$db_name_to_backup', frequency: '$target_frequency'"
                    echo ""

                    # Call the actual backup function and capture its output (the new file path)
                    # and its exit status.
                    local new_local_backup_file_path=""
                    local actual_backup_exit_status=0
                    
                    # Use a subshell to capture stdout and stderr separately,
                    # and then evaluate the exit status.
                    local temp_output
                    temp_output=$(perform_actual_backup "$target_frequency" "$db_name_to_backup" 2>&1)
                    actual_backup_exit_status=$?
                    
                    # Check if the output contains the file path (indicating success)
                    # The file path is the last line of stdout from perform_actual_backup on success.
                    # If it failed, perform_actual_backup returns an empty string on stdout.
                    new_local_backup_file_path=$(echo "$temp_output" | tail -n 1)

                    # Log the output from perform_actual_backup (which includes its own logs now)
                    echo "$temp_output"

                    if [ "$actual_backup_exit_status" -eq 0 ] && [ -n "$new_local_backup_file_path" ]; then
                        log_message_plp INFO "Backup for project '$project_name', database '$db_name_to_backup' (frequency: '$target_frequency') completed successfully. File: '$new_local_backup_file_path'"
                        DATABASE_BACKUP_SUMMARY+=("$project_name|$db_name_to_backup|SUCCESS|$new_local_backup_file_path")
                    else
                        log_message_plp ERROR "Backup for project '$project_name', database '$db_name_to_backup' (frequency: '$target_frequency') FAILED (Actual Backup Exit Status: $actual_backup_exit_status)."
                        DATABASE_BACKUP_SUMMARY+=("$project_name|$db_name_to_backup|FAILED|N/A")
                        project_has_db_backup_failures=1 # Mark that this project had a DB backup failure
                    fi
                done # End of database loop

		echo ""
		echo "-----------------------------"
                echo "All Databases Complete"
                echo "-----------------------------"
                echo "Proceeding..."
                echo ""
                echo ""


                # --- Centralized Cloud Sync and Final Local Cleanup (after all DBs are processed for this project) ---
                if [[ "$BACKUP_TYPE" == "cloud" || "$BACKUP_TYPE" == "both" ]]; then
                    echo ""
                    log_message_plp INFO "Performing Centralized Cloud Operations" 
                    echo "Project: '$project_name' | Frequency: '$target_frequency'"
		    echo ""
                    local local_source_dir_for_sync="$LOCAL_BACKUP_ROOT/$target_frequency"
                    local s3_target_path_for_sync="${S3_FULL_PATH}${target_frequency}/"
                    local ttl_var_name="TTL_$(echo "$target_frequency" | tr '[:lower:]' '[:upper:]')_BACKUP"
                    local retention_minutes="${!ttl_var_name:-0}"
                    local cloud_ops_successful=0 # Flag for cloud operations success

                    # Check if there were any successful local backups for *this project* to sync
                    local successful_local_backups_for_current_project_found=0 # NEW variable
                    for entry in "${DATABASE_BACKUP_SUMMARY[@]}"; do
                        local entry_proj_name=$(echo "$entry" | cut -d'|' -f1)
                        local entry_status=$(echo "$entry" | cut -d'|' -f3)

                        if [[ "$entry_proj_name" == "$project_name" ]] && [[ "$entry_status" == "SUCCESS" ]]; then
                            successful_local_backups_for_current_project_found=1
                            break # Found at least one successful backup for this project, so we can proceed with cloud sync
                        fi
                    done

                    if [ "$successful_local_backups_for_current_project_found" -eq 0 ]; then # Use the new, corrected flag
			echo ""
                        log_message_plp WARN "No successful local database backups for project '$project_name' to synchronize to cloud." 
			echo "Skipping cloud operations."
			echo ""
                    else
                        # Now, all cloud providers (s3, r2, b2) will use the same functions,
                        # and the logic inside storage_cloud.sh will differentiate.
                        if [[ "$BACKUP_TYPE" == "both" ]]; then
                            echo "" 
                            log_mesage_plp INFO "Cloud provider: '$CLOUD_STORAGE_PROVIDER' | BACKUP_TYPE: 'both'."
                            echo "Synchronizing local directory '$local_source_dir_for_sync' | To Cloud Path: '$s3_target_path_for_sync'."
                            if sync_to_cloud_s3 "$local_source_dir_for_sync" "$s3_target_path_for_sync"; then # Function name remains for compatibility
                                log_message_plp INFO "Project Project: '$project_name' | Frequency: '$target_frequency'" 
				echo "Completed Successfully."
				echo ""
                                cloud_ops_successful=1
                            else
                                log_message_plp ERROR "Centralized cloud synchronization failed for project '$project_name', frequency '$target_frequency'."
                                project_has_db_backup_failures=1 # Mark project as failed due to cloud sync failure
                            fi
                        elif [[ "$BACKUP_TYPE" == "cloud" ]]; then
                            log_message_plp INFO "Cloud provider: '$CLOUD_STORAGE_PROVIDER' | BACKUP_TYPE is 'cloud'."
			    echo "Uploading new files only from '$local_source_dir_for_sync' to '$s3_target_path_for_sync'."
                            # Use the s3_upload_only_sync function (name remains for compatibility)
                            if s3_upload_only_sync "$local_source_dir_for_sync" "$s3_target_path_for_sync"; then
                                log_message_plp INFO "All new files successfully uploaded to cloud."
				echo ""
                                cloud_ops_successful=1
                            else
                                log_message_plp ERROR "Some new files failed to upload to cloud. Cloud backup for this run may be incomplete."
                                project_has_db_backup_failures=1 # Mark project as failed due to cloud upload failure
                            fi
                        fi

                        # Cloud cleanup always runs if cloud operations were attempted and uploads were successful
                        if [ "$cloud_ops_successful" -eq 1 ]; then
                            log_message_plp INFO "Performing cloud cleanup with retention "$retention_minutes" minutes in '$s3_target_path_for_sync'."
                            if ! cleanup_cloud_s3 "$s3_target_path_for_sync" "$retention_minutes" "*.zip"; then # Function name remains for compatibility
                                log_message_plp WARN "Cloud cleanup failed for '$s3_target_path_for_sync'."
                                # Do not set project_has_db_backup_failures=1 for cleanup warnings.
                            fi
                        fi

                        # If BACKUP_TYPE is 'cloud' (and not 'both'), remove all local copies after successful cloud operations
                        if [[ "$BACKUP_TYPE" == "cloud" ]]; then
                            log_message_plp INFO "BACKUP_TYPE: 'cloud'."
                            echo "Removing all local backups from '$local_source_dir_for_sync' after successful cloud operations."
                            # Use find and xargs for robust deletion of files within the directory
                            if ! sudo find "$local_source_dir_for_sync" -maxdepth 1 -name "*.zip" -type f -print0 | xargs -0 sudo rm -f; then
                                log_message_plp WARN "Failed to remove local files from '$local_source_dir_for_sync' after cloud operations."
                            else
                                log_message_plp INFO "All local backups removed from '$local_source_dir_for_sync'."
				echo ""
                            fi
                        fi
                    fi # End of if successful_local_backups_for_current_project_found
                fi
                # --- End Centralized Cloud Sync and Final Local Cleanup ---

                if [ "$project_has_db_backup_failures" -eq 0 ]; then
		    echo ""
                    log_message_plp INFO "All database backups and cloud operations for"
                    echo "Project '$project_name' | Status: PASSED."
                    successful_projects=$((successful_projects + 1))
                    processed_project_statuses+=("PASSED")
                else
		    echo ""
                    log_message_plp ERROR "One or more database backups or cloud operations FAILED for project '$project_name'."
		    echo "Project '$project_name' | Status: FAILED."
                    failed_projects=$((failed_projects + 1))
                    processed_project_statuses+=("FAILED")
                fi

            else # Project preflight failed
                log_message_plp ERROR "Project preflight FAILED for '$project_name' (Exit Status: $project_preflight_status). Skipping database backups for this project."
                failed_projects=$((failed_projects + 1))
                processed_project_statuses+=("FAILED (Preflight)")
            fi
            processed_project_names+=("$project_name") # Store the name for the final report
            echo "" # Add a blank line for readability between project executions
        done
    fi

    # 5. Print final project summary
    echo "----------------------------------------------------------------"
    log_message_plp INFO "Finished processing all project entries."
    log_message_plp INFO "Summary: Total Projects Processed: $total_processed_projects, Successful: $successful_projects, Failed: $failed_projects"
    echo "----------------------------------------------------------------"
    echo ""
    echo ""

    # --- Final Project Processing Report ---
    echo "" # Blank line before final report
    echo "----------------------------------------"
    echo "Final Project Processing Report:"
    echo "----------------------------------------"
    printf "%-50s | %s\n" "Project Name" "Execution Status"
    echo "----------------------------------------"

    if [ "$total_processed_projects" -eq 0 ]; then
        printf "%-50s | %s\n" "No projects processed" "N/A"
    else
        for i in "${!processed_project_names[@]}"; do
            printf "%-50s | %s\n" "${processed_project_names[$i]}" "${processed_project_statuses[$i]}"
        done
    fi

    echo "----------------------------------------"
    echo "Total: $total_processed_projects, Successful: $successful_projects, Failed: $failed_projects"
    echo "----------------------------------------"
    echo "" # Add a blank line after the report

    # --- Database Backup Summary Report ---
    echo "" # Blank line before DB summary report
    echo "----------------------------------------------------------------------------------------------------"
    echo "Database Backup Summary Report for Frequency: '$target_frequency'"
    echo "----------------------------------------------------------------------------------------------------"
    printf "%-20s | %-20s | %-10s | %s\n" "Project" "Database" "Status" "File Path (if successful)"
    echo "----------------------------------------------------------------------------------------------------"

    if [ ${#DATABASE_BACKUP_SUMMARY[@]} -eq 0 ]; then
        printf "%-20s | %-20s | %-10s | %s\n" "N/A" "No databases processed" "N/A" "N/A"
    else
        for entry in "${DATABASE_BACKUP_SUMMARY[@]}"; do
            IFS='|' read -r proj_name db_name status file_path <<< "$entry"
            printf "%-20s | %-20s | %-10s | %s\n" "$proj_name" "$db_name" "$status" "$file_path"
        done
    fi

    echo "----------------------------------------------------------------------------------------------------"
    echo "" # Add a blank line after the report

    # 6. Determine overall exit status
    if [ "$failed_projects" -gt 0 ] || [ "$successful_projects" -eq 0 -a "$total_processed_projects" -gt 0 ]; then
        log_message_plp ERROR "One or more projects or database backups failed. Please review the log messages and reports above for details."
        return 1
    else
        log_message_plp INFO "All enabled projects and their database backups completed successfully."
        return 0
    fi
}

# --- Main Execution ---
# Call the main processing function with all command-line arguments.
process_project_list "$@"

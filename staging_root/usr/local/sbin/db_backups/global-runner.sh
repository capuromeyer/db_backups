#!/bin/bash
# =============================================================================
# Script: global-runner.sh
# Purpose: Main orchestration script for database backups. It accepts a backup
#          frequency as an argument, filters projects based on their configured
#          frequency settings, and then initiates the backup process for all
#          enabled projects.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.153500
# Project Version: 1.0.0
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: sudo ./global-runner.sh <frequency>
#    <frequency> can be: minutely, hourly, daily, weekly, monthly, yearly
#
# Notes:
# - This script must be run as root.
# - It reads the main manifest file and dynamically filters projects
#   based on the provided frequency argument and each project's
#   BACKUP_FREQUENCY_<FREQUENCY> setting.
# =============================================================================

set -euo pipefail

# --- Global Variables for Runner ---
# These will be set during setup_environment
CALLER_SCRIPT_DIR=""
LIB_DIR=""
PREFLIGHT_SCRIPT_PATH="" # Path to global_preflight.sh
MAIN_MANIFEST_FILE="/etc/db_backups/db_backups.conf"
CURRENT_FREQUENCY="" # Set from command line argument
CURRENT_FREQUENCY_UPPERCASE="" # Uppercase version of CURRENT_FREQUENCY
# Temporary file to hold paths of UNIQUE projects from master_config_file_utils.sh
UNIQUE_CONFIG_FILES_TEMP_PATH=""
# Temporary file to hold paths of projects enabled for this frequency
FINAL_FILTERED_PROJECT_LIST_FILE=""

# --- Logging Helper Function ---
# Function: log_message
# Purpose: Standardized logging helper for messages from this script.
# Arguments: $1 - Log level (INFO, WARN, ERROR)
#            $2 - Message to log
log_message() {
    local level="$1"
    local message="$2"
    # Direct all messages to standard output
    case "$level" in
        INFO)    echo "[GLOBAL RUNNER] INFO $message" ;;
        WARN)    echo "[GLOBAL RUNNER] WARN $message" ;;
        ERROR)   echo "[GLOBAL RUNNER] ERROR $message" ;;
        *)       echo "[GLOBAL RUNNER] UNKNOWN $message" ;; # Fallback for unknown levels
    esac
}

# -----------------------------------------------------------------------------
# Function: ensure_root
# Purpose : Exit if not running as root
# -----------------------------------------------------------------------------
ensure_root() {
    if [[ $EUID -ne 0 ]]; then
        log_message ERROR "This script must be run as root. Please rerun with sudo."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Function: print_header
# Purpose : Print start banner and timestamp
# -----------------------------------------------------------------------------
print_header() {
    echo ""
    echo ""
    echo "==============================================================================="
    echo ""
    echo "           BACKUP PROCESS STARTED - Frequency: $(echo "$CURRENT_FREQUENCY" | tr '[:lower:]' '[:upper:]')"
    echo "           Time: $(date)"
    echo ""
    echo "==============================================================================="
    echo ""
}

# -----------------------------------------------------------------------------
# Function: section_heading
# Purpose : Print script logic separator with a custom title
# Usage   : section_heading "My Custom Title"
# -----------------------------------------------------------------------------
section_heading() {
    local title="${1:-START - Section Starts}"
    echo "_______________________________________________________________________________"
    echo
    echo "----------------------------------------------------------------"
    echo " ${title}"
    echo "----------------------------------------------------------------"
    echo
}

# -----------------------------------------------------------------------------
# Function: section_footer
# Purpose : Print script logic separator with a custom title
# Usage   : section_footer "My Custom Title"
# -----------------------------------------------------------------------------
section_footer() {
    local footer_title="${1:-ENDS - Sections Ends}"
    echo "----------------------------------------------------------------"
    echo " ${footer_title}"
    echo "----------------------------------------------------------------"
    echo
}

# -----------------------------------------------------------------------------
# Function: source_libraries
# Purpose : Source common utility and workflow libraries
# -----------------------------------------------------------------------------
source_libraries() {
    log_message INFO "Loading common libraries..."
    source "$LIB_DIR/utils.sh" || { log_message ERROR "Failed to source $LIB_DIR/utils.sh."; exit 1; }
    source "$LIB_DIR/workflow_utils.sh" || { log_message ERROR "Failed to source $LIB_DIR/workflow_utils.sh."; exit 1; }

    # Source master_config_file_utils.sh and verify function availability
    source "$LIB_DIR/master_config_file_utils.sh" || { log_message ERROR "Failed to source $LIB_DIR/master_config_file_utils.sh"; exit 1; }
    if ! type -t detect_and_report_duplicates &> /dev/null; then
        log_message ERROR "Function 'detect_and_report_duplicates' not found after sourcing $LIB_DIR/master_config_file_utils.sh. Check the file content and permissions."
        exit 1
    fi

    echo "Common libraries loaded."
    echo "proceeding ..."
    echo ""
}

# -----------------------------------------------------------------------------
# Function: setup_environment
# Purpose : Define script-wide variables and arrays
# Arguments: $1 - The frequency passed to the script (e.g., "hourly")
# -----------------------------------------------------------------------------
setup_environment() {
    log_message INFO "Setting up environment variables..."
    CALLER_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
    LIB_DIR="$CALLER_SCRIPT_DIR/lib"
    PREFLIGHT_SCRIPT_PATH="$CALLER_SCRIPT_DIR/global_preflight.sh" # Path to the global preflight script

    # Validate and set CURRENT_FREQUENCY
    if [ -z "$1" ]; then
        log_message ERROR "No backup frequency provided. Usage: $0 <frequency> (e.g., hourly, daily)"
        exit 1
    fi
    CURRENT_FREQUENCY="$1"
    CURRENT_FREQUENCY_UPPERCASE=$(echo "$CURRENT_FREQUENCY" | tr '[:lower:]' '[:upper:]')

    # Validate allowed frequencies
    local allowed_frequencies=("minutely" "hourly" "daily" "weekly" "monthly" "yearly")
    local is_valid_frequency=0
    for freq_check in "${allowed_frequencies[@]}"; do
        if [[ "$CURRENT_FREQUENCY" == "$freq_check" ]]; then
            is_valid_frequency=1
            break
        fi
    done
    if [ "$is_valid_frequency" -eq 0 ]; then
        log_message ERROR "Invalid backup frequency provided: '$CURRENT_FREQUENCY'. Allowed frequencies: ${allowed_frequencies[*]}."
        exit 1
    fi

    # Create temporary files
    UNIQUE_CONFIG_FILES_TEMP_PATH=$(mktemp /tmp/unique_projects_XXXXXX.txt)
    FINAL_FILTERED_PROJECT_LIST_FILE=$(mktemp /tmp/final_filtered_projects_XXXXXX.txt)
    echo "Temporary file for unique projects created at: '$UNIQUE_CONFIG_FILES_TEMP_PATH'"
    echo "Temporary file for final filtered projects created at: '$FINAL_FILTERED_PROJECT_LIST_FILE'"

    echo "Environment setup complete for frequency: '$CURRENT_FREQUENCY'."
    echo "proceeding..."
    echo ""
}

# -----------------------------------------------------------------------------
# Function: perform_global_preflight
# Purpose : Source and run global preflight checks
# -----------------------------------------------------------------------------
perform_global_preflight() {
    log_message INFO "Performing global preflight checks..."
    source "$PREFLIGHT_SCRIPT_PATH" || { log_message ERROR "Failed to load global preflight script from '$PREFLIGHT_SCRIPT_PATH'."; exit 1; }
    run_all_preflight_checks; status=$?
    if [[ $status -ne 0 ]]; then
        log_message ERROR "Global preflight checks failed (status: $status)."
        exit 1
    fi
    echo "Global preflight checks passed."
    echo "proceeding..."
    echo ""
}

# -----------------------------------------------------------------------------
# FUNCTION: filter_projects_by_frequency
# Purpose : Calls detect_and_report_duplicates to get unique project list,
#           then filters this list based on the current frequency's 'on'/'off' setting.
#           Populates FINAL_FILTERED_PROJECT_LIST_FILE.
# Globals : MAIN_MANIFEST_FILE, CURRENT_FREQUENCY_UPPERCASE, UNIQUE_CONFIG_FILES_TEMP_PATH, FINAL_FILTERED_PROJECT_LIST_FILE
# Outputs : Log messages and the duplicate report from master_config_file_utils.sh
# Returns : 0 on success (at least one project enabled), 1 if no projects enabled or fatal error.
# -----------------------------------------------------------------------------
filter_projects_by_frequency() {
    echo "Starting project verifications for frequency '$CURRENT_FREQUENCY'..."

    # Ensure the master config file exists
    if [ ! -f "$MAIN_MANIFEST_FILE" ]; then
        log_message ERROR "Master manifest file not found: '$MAIN_MANIFEST_FILE'. Cannot proceed with filtering."
        return 1
    fi

    # 1. Call detect_and_report_duplicates to get the list of unique, valid project paths
    # It outputs the temp file path on the first line, then its report.
    local detect_output
    if ! detect_output=$(detect_and_report_duplicates "$MAIN_MANIFEST_FILE" 2>&1); then
        log_message ERROR "Failed to run detect_and_report_duplicates on manifest '$MAIN_MANIFEST_FILE'."
        log_message ERROR "Output from detect_and_report_duplicates: $detect_output"
        return 1
    fi

    # Extract the unique config file path (first line of output)
    UNIQUE_CONFIG_FILES_TEMP_PATH=$(echo "$detect_output" | head -n 1)
    # Print the rest of the output (the duplicate report)
    echo "$detect_output" | tail -n +2

    if [ -z "$UNIQUE_CONFIG_FILES_TEMP_PATH" ] || [ ! -f "$UNIQUE_CONFIG_FILES_TEMP_PATH" ]; then
        log_message ERROR "Unique config files list was not created or found by detect_and_report_duplicates."
        return 1
    fi

    local total_projects_from_unique_list=0
    local projects_enabled_count=0
    local projects_skipped_count=0
    local projects_failed_to_source_count=0

    # New arrays to store project names and their statuses for the detailed report
    local -a filtered_project_names=()
    local -a filtered_project_statuses=()

    # Clear the final filtered file before writing
    > "$FINAL_FILTERED_PROJECT_LIST_FILE"

    # 2. Iterate through the unique project paths and filter by frequency setting
    while IFS= read -r project_config_path; do
        # --- NEW: Skip empty lines and comment lines ---
        local trimmed_path=$(echo "$project_config_path" | xargs) # Trim whitespace
        if [[ -z "$trimmed_path" || "$trimmed_path" =~ ^# ]]; then
            continue # Skip empty lines and comments without logging
        fi
        # --- END NEW ---

        total_projects_from_unique_list=$((total_projects_from_unique_list + 1))
        local project_name=$(basename "$trimmed_path") # Use trimmed_path here

        echo ""
        log_message INFO "Evaluating project '$project_name' for '$CURRENT_FREQUENCY' frequency..."

        # Temporarily source the project config file to check its frequency setting
        # Use a subshell to prevent variables from leaking into the main script's environment
        # and to handle sourcing errors gracefully.
        local freq_setting=""
        local temp_freq_var_name="BACKUP_FREQUENCY_${CURRENT_FREQUENCY_UPPERCASE}"
        # Source with redirection to /dev/null to suppress its output
        if ! freq_setting=$( ( source "$trimmed_path" >/dev/null 2>&1; echo "${!temp_freq_var_name:-}" ) ); then # Use trimmed_path here
            log_message WARN "Failed to source project config '$trimmed_path' to check frequency. Skipping project '$project_name'. Check syntax or permissions."
            projects_failed_to_source_count=$((projects_failed_to_source_count + 1))
            filtered_project_names+=("$project_name")
            filtered_project_statuses+=("SKIPPED (Failed to Source)")
            continue
        fi

        # Default to 'on' if the frequency setting is not explicitly defined
        if [ -z "$freq_setting" ]; then
            log_message WARN "Frequency setting 'BACKUP_FREQUENCY_${CURRENT_FREQUENCY_UPPERCASE}' not defined in '$project_name'. Assuming 'on'."
            freq_setting="on"
        fi

        if [ "$freq_setting" == "on" ]; then
            echo "Project '$project_name' is ENABLED for '$CURRENT_FREQUENCY' frequency. Adding to final list."
            echo "$trimmed_path" >> "$FINAL_FILTERED_PROJECT_LIST_FILE" # Use trimmed_path here
            projects_enabled_count=$((projects_enabled_count + 1))
            filtered_project_names+=("$project_name")
            filtered_project_statuses+=("ENABLED")
        elif [ "$freq_setting" == "off" ]; then
            echo "Project '$project_name' is DISABLED for '$CURRENT_FREQUENCY' frequency. Skipping."
            projects_skipped_count=$((projects_skipped_count + 1))
            filtered_project_names+=("$project_name")
            filtered_project_statuses+=("DISABLED")
        else
            log_message WARN "Unknown frequency setting '$freq_setting' for 'BACKUP_FREQUENCY_${CURRENT_FREQUENCY_UPPERCASE}' in '$project_name'. Skipping."
            projects_skipped_count=$((projects_skipped_count + 1))
            filtered_project_names+=("$project_name")
            filtered_project_statuses+=("SKIPPED (Unknown Setting)")
        fi
    done < "$UNIQUE_CONFIG_FILES_TEMP_PATH"

    echo ""
    echo "Projects filtering by frequency complete."
    echo "proceeding..."
    echo ""

    # --- NEW: Detailed Project Frequency Filtering Report ---
    echo "----------------------------------------------------------------"
    echo "Project Frequency Filtering Report for: '$CURRENT_FREQUENCY'"
    echo "----------------------------------------------------------------"
    printf "%-50s | %s\n" "Project Name" "Frequency Status"
    echo "----------------------------------------------------------------"

    if [ ${#filtered_project_names[@]} -eq 0 ]; then
        printf "%-50s | %s\n" "No projects evaluated for this frequency" "N/A"
    else
        for i in "${!filtered_project_names[@]}"; do
            printf "%-50s | %s\n" "${filtered_project_names[$i]}" "${filtered_project_statuses[$i]}"
        done
    fi
    echo "----------------------------------------------------------------"
    echo "Total Evaluated: $total_projects_from_unique_list, Enabled: $projects_enabled_count, Disabled/Skipped: $((projects_skipped_count + projects_failed_to_source_count))"
    echo "----------------------------------------------------------------"
    echo ""
    # --- END NEW ---

    if [ "$projects_enabled_count" -eq 0 ]; then
        log_message INFO "No projects are enabled for '$CURRENT_FREQUENCY' frequency. Nothing to backup for this run."
        return 1 # Indicate no projects to process
    fi

    log_message INFO "Final filtered project list saved to '$FINAL_FILTERED_PROJECT_LIST_FILE'."
    echo ""
    echo "Summary: Projects from Unique List: $total_projects_from_unique_list, Enabled: $projects_enabled_count, Skipped: $projects_skipped_count, Failed to Source: $projects_failed_to_source_count"
    echo "Project filtering complete."
    echo ""

    return 0
}

# -----------------------------------------------------------------------------
# FUNCTION: run_project_processor
# Purpose : Calls the project_list_processor.sh script with the filtered list
# Globals : FINAL_FILTERED_PROJECT_LIST_FILE, CURRENT_FREQUENCY
# -----------------------------------------------------------------------------
run_project_processor() {
    log_message INFO "Starting project processing for enabled projects..."
    log_message INFO "Calling project_list_processor.sh with filtered list: '$FINAL_FILTERED_PROJECT_LIST_FILE' and frequency '$CURRENT_FREQUENCY'."

    # Call the project_list_processor.sh script with the filtered list
    # The project_list_processor.sh script expects the list file as the first arg
    # and the frequency as the second arg.
    /usr/local/sbin/db_backups/lib/project_list_processor.sh "$FINAL_FILTERED_PROJECT_LIST_FILE" "$CURRENT_FREQUENCY"
    local processor_exit_status=$?

    if [ "$processor_exit_status" -eq 0 ]; then
        log_message INFO "All enabled projects processed successfully by project_list_processor.sh."
        echo ""
        overall_backup_status=0
    else
        log_message ERROR "Some enabled projects encountered issues during processing by project_list_processor.sh (Exit Status: $processor_exit_status). Please check the logs above."
        echo ""

        overall_backup_status=1
    fi

    log_message INFO "Project processing finished."
    echo ""
}

# -----------------------------------------------------------------------------
# Function: print_final_summary
# Purpose : Print overall summary banner and exit
# Globals : overall_backup_status, CURRENT_FREQUENCY
# -----------------------------------------------------------------------------
print_final_summary() {
    echo "-------------------------------------------------------------------------------"
    if [[ $overall_backup_status -eq 0 ]]; then
        log_message INFO "All enabled projects for $CURRENT_FREQUENCY completed OK."
    else
        log_message ERROR "Some enabled projects failed in $CURRENT_FREQUENCY cycle."
    fi
    echo ""
    echo "$(echo "$CURRENT_FREQUENCY" | tr '[:lower:]' '[:upper:]') Backup Cycle finished."
    echo ""
    echo "==============================================================================="
    echo "$(echo "$CURRENT_FREQUENCY" | tr '[:lower:]' '[:upper:]') Backup Process finished at | $(date)"
    echo "==============================================================================="
    exit $overall_backup_status
}

# -----------------------------------------------------------------------------
# Main execution flow: call each function in order
# -----------------------------------------------------------------------------

# Initialize overall backup status
overall_backup_status=0

# 1. Ensure we have root privileges before doing anything
ensure_root

# 2. Print the start banner with a timestamp for logging and visibility
print_header

# 3. Setup environment variables and parse arguments
setup_environment "$@"

# 4. Load shared helper libraries (utils, workflow_utils, master_config_file_utils)
source_libraries

# 5. Run global preflight checks to validate system prerequisites
section_heading "GLOBAL PREFLIGHT - Starting System Checks"
perform_global_preflight
section_footer "GLOBAL PREFLIGHT - System Checks Ends"

# 6. Load and filter projects based on frequency settings
section_heading "PROJECT VALIDATION - Starting Project validation for '$CURRENT_FREQUENCY'"
if ! filter_projects_by_frequency; then # Renamed function call
    # If no projects are enabled for this frequency, exit successfully (nothing to do)
    # This check is important to differentiate between "no projects to process" and a "failure"
    if [ "$overall_backup_status" -eq 0 ]; then # Only exit 0 if no prior errors occurred
        log_message INFO "No projects found enabled for '$CURRENT_FREQUENCY'. Exiting successfully."
        exit 0
    else
        # If filter_projects_by_frequency failed for a reason other than no projects enabled, exit with error
        log_message ERROR "Failed to load and filter projects. Exiting."
        exit 1
    fi
fi
section_footer "PROJECT VALIDATION - Project validation Ends"

# 7. Run the project list processor for the filtered projects
section_heading "PROJECT PROCESSING - Starting Backup Execution for Enabled Projects"
run_project_processor
section_footer "PROJECT PROCESSING - Backup Execution Ends"

# 8. Clean up temporary filtered project list files
if [ -f "$UNIQUE_CONFIG_FILES_TEMP_PATH" ]; then
    log_message INFO "Cleaning up temporary unique project list file: '$UNIQUE_CONFIG_FILES_TEMP_PATH'."
    rm -f "$UNIQUE_CONFIG_FILES_TEMP_PATH" || log_message WARN "Failed to remove temporary file: '$UNIQUE_CONFIG_FILES_TEMP_PATH'."
fi
if [ -f "$FINAL_FILTERED_PROJECT_LIST_FILE" ]; then
    log_message INFO "Cleaning up temporary final filtered project list file: '$FINAL_FILTERED_PROJECT_LIST_FILE'."
    rm -f "$FINAL_FILTERED_PROJECT_LIST_FILE" || log_message WARN "Failed to remove temporary file: '$FINAL_FILTERED_PROJECT_LIST_FILE'."
fi

# 9. Print final summary and exit
print_final_summary

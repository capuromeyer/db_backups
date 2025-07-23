#!/bin/bash
# -----------------------------------------------------------------------------
# Script: test-runner.sh
# Purpose: Orchestrates backup 
# Developed by: Alejandro Capuro (Project Lead & Logic Design)
# Implemented by: Jules (AI Assistant, under guidance)
# Copyright: (c) 2025 Alejandro Capuro. All rights reserved.
# File Version: 20250705.170000
# Project Version: 1.0.0
# -----------------------------------------------------------------------------

set -euo pipefail

# -----------------------------------------------------------------------------
# Function: ensure_root
# Purpose : Exit if not running as root
# -----------------------------------------------------------------------------
ensure_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "[TESTER_ERROR] This script must be run as root. Please rerun with sudo."
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
    echo "                           BACKUP PROCESS STARTED"
    echo "                   Time: $(date)"
    echo ""
    echo "==============================================================================="
    echo ""
}


# -----------------------------------------------------------------------------
# Function: print_separator
# Purpose : Print script logic separator with a custom title
# Usage   : print_separator "My Custom Title"
# -----------------------------------------------------------------------------
section_heading() {
    local title="${1:-STRAT - Section Starts}"

    # top underline
    echo "_______________________________________________________________________________"
    echo

    # dashed box with title
    echo "----------------------------------------------------------------"
    echo " ${title}"
    echo "----------------------------------------------------------------"
    echo
}

# -----------------------------------------------------------------------------
# Function: print_separator
# Purpose : Print script logic separator with a custom title
# Usage   : print_separator "My Custom Title"
# -----------------------------------------------------------------------------
section_footer() {
    local footer_title="${1:-ENDS - Sections Ends}"

    # dashed box with title
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
    source "$(dirname "${BASH_SOURCE[0]}")/lib/utils.sh" || { echo "[ERROR] Failed to source lib/utils.sh."; exit 1; }
    source "$(dirname "${BASH_SOURCE[0]}")/lib/workflow_utils.sh" || { echo "[ERROR] Failed to source lib/workflow_utils.sh."; exit 1; }
}

# -----------------------------------------------------------------------------
# Function: setup_environment
# Purpose : Define script-wide variables and arrays
# -----------------------------------------------------------------------------
setup_environment() {
    CALLER_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    LIB_DIR="$CALLER_SCRIPT_DIR/lib"
    PREFLIGHT_SCRIPT_PATH="$CALLER_SCRIPT_DIR/preflight.sh"
    MAIN_MANIFEST_FILE="/etc/db_backups/db_backups.conf"
    CURRENT_FREQUENCY="hourly"

    SQLITE_DB_FILE=""
    declare -a EXISTING_AND_READABLE_CONFIG_PATHS=()
}

# -----------------------------------------------------------------------------
# Function: perform_root_check
# Purpose : Verify root privileges via utility function
# -----------------------------------------------------------------------------
perform_root_check() {
    echo "Verifying root privileges..."
    check_root || exit 1
    echo ""
}

# -----------------------------------------------------------------------------
# Function: perform_global_preflight
# Purpose : Source and run global preflight checks
# -----------------------------------------------------------------------------
perform_global_preflight() {
    echo "[TESTER_INFO] Performing global preflight checks..."
    source "$PREFLIGHT_SCRIPT_PATH" || { echo "[ERROR_SOURCING] Failed to load preflight script."; exit 1; }
    perform_global_preflight_checks; status=$?
    if [[ $status -ne 0 ]]; then
        echo "[TESTER_ERROR] Global preflight checks failed (status: $status)."
        exit 1
    fi
    echo "[TESTER_INFO] Global preflight checks passed."
    echo ""
}

# -----------------------------------------------------------------------------
# FUNCTION: load_and_validate_manifest
# Purpose : Source config processor, validate manifest entries
# Globals : MAIN_MANIFEST_FILE
# Outputs : stderr: validation report
# Returns : exit on fatal error, 0 if at least one valid config
# -----------------------------------------------------------------------------
load_and_validate_manifest() {
    echo "[MANIFEST] Loading manster config file and validating ..."
    source "/usr/local/sbin/db_backups/lib/master_config_file_utils.sh" \
        || { echo "[ERROR] Unable to load /usr/local/sbin/db_backups/lib/master_config_file_utils.sh"; exit 1; }

    process_and_report_configs "$MAIN_MANIFEST_FILE"
    local rc=$?
    if (( rc != 0 )); then
        echo "[TESTER_INFO] No valid configuration files found. Nothing to backup."
        exit 0
    fi
    echo "[MANIFEST] Valid configuration files found. Proceeding..."
    echo ""
}


# -----------------------------------------------------------------------------
# FUNCTION: load_and_detect_duplicates
# Purpose : Identify and report duplicate config files by project name,
#           and capture the path to the generated unique files list.
# Globals : MAIN_MANIFEST_FILE, UNIQUE_CONFIG_FILES_PATH (new global)
# Outputs : stdout: The full report and all informational/error messages from
#                   detect_and_report_duplicates.
# Returns : exit on fatal error, 0 otherwise
# -----------------------------------------------------------------------------
load_and_detect_duplicates() {
    echo "[MANIFEST] Checking for duplicate configuration files..."
    local full_output # Variable to capture all stdout from detect_and_report_duplicates

    # Declare UNIQUE_CONFIG_FILES_PATH as global.
    # Using 'export' makes it available to any child processes as well.
    export UNIQUE_CONFIG_FILES_PATH

    # Execute detect_and_report_duplicates and capture all its stdout.
    # The first line of this output will be the unique file path.
    full_output=$(detect_and_report_duplicates "$MAIN_MANIFEST_FILE")

    # Extract the first line from the captured output, which is the file path.
    UNIQUE_CONFIG_FILES_PATH=$(echo "$full_output" | head -n 1)

    # Print the rest of the captured output (which contains all reports and info)
    # after extracting the filename. This ensures all verbose output is shown.
    echo "$full_output" | tail -n +2 # Prints all lines from the second line onwards

    # Check if the file path was successfully extracted and the file exists
    if [[ -z "$UNIQUE_CONFIG_FILES_PATH" || ! -f "$UNIQUE_CONFIG_FILES_PATH" ]]; then
        echo "[ERROR] Unique files list was not created or found for manifest: $MAIN_MANIFEST_FILE"  # This error goes to stderr
        exit 1
    fi

    echo ""
    echo "[MANIFEST] Duplicate check complete."
    echo ""
    echo "[MANIFEST] Unique configuration files list saved at:"
    echo "$UNIQUE_CONFIG_FILES_PATH"
    echo ""

    # You can now use the 'UNIQUE_CONFIG_FILES_PATH' global variable for the next step
    # For example, to loop through the unique files:
    # while IFS= read -r config_file; do
    #     # Skip header lines if they are comments
    #     if [[ "$config_file" =~ ^# ]]; then
    #         continue
    #     fi
    #     echo "Processing unique config: $config_file"
    #     # Add your logic here to backup database dumps
    # done < "$UNIQUE_CONFIG_FILES_PATH"
}

# -----------------------------------------------------------------------------
# FUNCTION: load_and_validate_manifest
# Purpose : Source config processor, validate manifest entries
# Globals : MAIN_MANIFEST_FILE
# Outputs : stderr: validation report
# Returns : exit on fatal error, 0 if at least one valid config
# -----------------------------------------------------------------------------
load_and_validate_projects() {
    echo "[PORJECTS] Loading projects config file and validating ..."
    source "/usr/local/sbin/db_backups/lib/project_preflight.sh" \
        || { echo "[ERROR] Unable to load /usr/local/sbin/db_backups/lib/project_preflight.sh"; exit 1; }

    process_and_report_configs "$MAIN_MANIFEST_FILE"
    local rc=$?
    if (( rc != 0 )); then
        echo "[TESTER_INFO] No valid configuration files found. Nothing to backup."
        exit 0
    fi
    echo "[MANIFEST] Valid configuration files found. Proceeding..."
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
        echo "[TESTER_INFO] All projects for $CURRENT_FREQUENCY completed OK."
    else
        echo "[TESTER_ERROR] Some projects failed in $CURRENT_FREQUENCY cycle."
    fi
    echo "TESTER Backup Cycle finished."
    echo "==============================================================================="
    echo "TESTER Backup Process finished at | $(date)"
    echo "==============================================================================="
    exit $overall_backup_status
}




load_global_preflight() {
    echo "Loading Global check ..."
    source "/usr/local/sbin/db_backups/global_preflight.sh" \
        || { echo "[ERROR] Unable to load core file /usr/local/sbin/db_backups/global_preflight.sh"; exit 1; }

    run_all_preflight_checks
}



load_project_list_processor() {
    PROJECT_LIST="$UNIQUE_CONFIG_FILES_PATH"

    echo "PARENT CALLER START --- Starting project processing..."

    # Call the project_list_processor.sh script
    sudo /usr/local/sbin/db_backups/lib/project_list_processor.sh "$PROJECT_LIST" "hourly"

    # Check the exit status of the project_list_processor.sh script
    if [ $? -eq 0 ]; then
        echo "All projects processed successfully."
    else
        echo "Some projects encountered issues during processing. Please check the logs."
    fi

    echo "PARENT CALLER ENDS -- Project processing finished."

}



# -----------------------------------------------------------------------------
# Main execution flow: call each function in order
# -----------------------------------------------------------------------------

# 1. Ensure we have root privileges before doing anything
ensure_root

# 2. Print the start banner with a timestamp for logging and visibility
print_header

# 3. Load shared helper libraries (utils and workflow functions)
source_libraries

# 4. Initialize environment variables and arrays used by the script
setup_environment

# 5. Double-check root privileges using the utility function (redundant safety)
perform_root_check

## 6. Run global preflight checks to validate system prerequisites
load_global_preflight

section_heading "MANIFEST - Starting Master Conf File Check"

# 7. Load the manifest file, strip comments/includes, and validate config paths
load_and_validate_manifest

# 8.  Load duplicate validator
load_and_detect_duplicates
section_footer "MANIFEST - Master Conf File Check Ends"

#9.
section_heading "PROJECTS - Starting Individual Projects Check"

load_project_list_processor

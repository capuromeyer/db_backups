# Developed by: Alejandro Capuro (Project Lead & Logic Design)
# Implemented by: Jules (AI Assistant, under guidance)

# lib/workflow_utils.sh: Functions for managing the backup workflow for individual projects.

# Processes a single project configuration file to perform backup based on frequency and preflight checks.
# Arguments:
#   $1: The path to the project configuration file.
#   $2: The current backup frequency (e.g., "hourly").
#   $3: The directory containing library scripts ($LIB_DIR).
#   $4: The path to the global preflight script ($PREFLIGHT_SCRIPT_PATH).
# Returns:
#   0 on success (backup executed or skipped), non-zero on failure.
process_project_config() {
    local project_config_file="$1"
    local current_frequency="$2"
    local LIB_DIR="$3"
    local PREFLIGHT_SCRIPT_PATH="$4"

    echo "-------------------------------------------------------------------------------"  # Ensure separator goes to stderr
    echo "[INFO] Processing project: $project_config_file for $current_frequency backups..."  # Ensure info messages go to stderr

    # Use a subshell to isolate sourcing of project config
    (
        # Export necessary variables to the subshell
        export CALLER_SCRIPT_DIR="$(dirname "$PREFLIGHT_SCRIPT_PATH")"
        export LIB_DIR="$LIB_DIR"
        export PREFLIGHT_SCRIPT_PATH="$PREFLIGHT_SCRIPT_PATH"
        export CURRENT_FREQUENCY="$current_frequency"

        # Disable nounset within the subshell when sourcing to allow variables in config files to be unset
        set +u
        # Source the project configuration file
        if ! source "$project_config_file"; then
            echo "[ERROR_CONFIG][$project_config_file] Failed to source project configuration file." >&2
            exit 101 # Specific exit code for sourcing failure
        fi
        # Re-enable nounset after sourcing, though project config may leave vars unset
        # It's safer to handle unset vars within the called functions if needed.
        # set -u # Decided against reenabling set -u here as project configs might legitimately leave vars unset.

        # Check the frequency flag for the current frequency
        local frequency_flag_var_name="BACKUP_FREQUENCY_$(echo "$current_frequency" | tr '[:lower:]' '[:upper:]')"
        local project_frequency_setting=""

        # Use declare -p to check if the variable is set and get its value safely
        if declare -p "$frequency_flag_var_name" &>/dev/null; then
            project_frequency_setting="${!frequency_flag_var_name}"
        fi

        # Convert setting to lowercase for case-insensitive comparison
        local lower_project_frequency_setting=$(echo "$project_frequency_setting" | tr '[:upper:]' '[:lower:]')

        # Check if the frequency is enabled for this project
        if [[ "$lower_project_frequency_setting" =~ ^(on|true|yes|1)$ ]]; then
            echo "[INFO][$project_config_file] Frequency flag ($current_frequency) is ON. Proceeding with backup..." >&2

            # Source the global preflight script again in the subshell to ensure functions are available
            if ! source "$PREFLIGHT_SCRIPT_PATH"; then
                echo "[ERROR_PREFLIGHT][$project_config_file] Failed to source global preflight script." >&2
                exit 102 # Specific exit code for preflight sourcing failure
            fi

            # Perform project-specific preflight checks (function assumed to be in preflight.sh)
            if ! perform_project_preflight_checks; then
                local project_preflight_status=$?
                 echo "[ERROR_PREFLIGHT][$project_config_file] Project preflight checks failed (status: $project_preflight_status)." >&2
                exit 103 # Specific exit code for project preflight failure
            fi
            echo "[INFO][$project_config_file] Project preflight checks passed." >&2

            # Source the backup orchestrator script
            if ! source "$LIB_DIR/backup_orchestrator.sh"; then
                echo "[CRITICAL_LIB][$project_config_file] Failed to source backup orchestrator script." >&2
                exit 104 # Specific exit code for orchestrator sourcing failure
            fi
            echo "[INFO][$project_config_file] Calling backup orchestrator..." >&2

            # Execute the backup cycle for the current frequency
            execute_backup_cycle "$current_frequency"
            local sub_exit_status=$?

            if [ $sub_exit_status -eq 0 ]; then
                echo "[SUCCESS][$project_config_file] Backup cycle completed successfully." >&2
                exit 0 # Success
            else
                echo "[ERROR_BACKUP][$project_config_file] Backup cycle failed (status: $sub_exit_status)." >&2
                exit $sub_exit_status # Propagate orchestrator's exit status
            fi
        else
            echo "[INFO][$project_config_file] Frequency flag ($current_frequency) is OFF or not set. Skipping backup." >&2
            exit 0 # Skipped is considered a success for the loop iteration
        fi
    )
    local project_run_status=$?
    return $project_run_status
}

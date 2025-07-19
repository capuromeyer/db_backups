#!/bin/bash
# -----------------------------------------------------------------------------
# Script: preflight.sh
# Purpose: Performs pre-run checks and setup for the db_backups scripts.
#          Provides functions for global (one-time) checks and per-project checks.
# Developed by: Alejandro Capuro (Project Lead & Logic Design)
# Implemented by: Jules (AI Assistant, under guidance)
# Copyright: (c) 2025 Alejandro Capuro. All rights reserved.
# File Version: 20250705.100000
# Project Version: 1.0.0
#
# Notes:
#   - This script is intended to be sourced.
#   - It defines functions:
#     - perform_global_preflight_checks()
#     - perform_project_preflight_checks()
#   - Root check should be performed by the calling script BEFORE calling
#     perform_global_preflight_checks().
# -----------------------------------------------------------------------------

# PREFLIGHT_SCRIPT_DIR is set to the directory of this script itself.
PREFLIGHT_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# =============================================================================
# FUNCTION: perform_initial_config_validation
# Purpose: Performs a basic validation of a project configuration file.
#          Intended to be called in a loop by frequency scripts BEFORE
#          attempting full preflight and execution for each project.
#          This function sources the config file in a subshell for isolation.
# Arguments:
#   $1: Path to the project configuration file to validate.
# Output (to STDOUT, pipe-separated):
#   "VALID|PROJECT_NAME_value|BACKUP_TYPE_value"
#   "INVALID|PROJECT_NAME_value_or_NA|BACKUP_TYPE_value_or_NA|Failure_Reason_String"
# Exit Code:
#   0 if the function itself ran correctly (regardless of config validity).
#   Caller should parse STDOUT to determine config validity.
# =============================================================================
perform_initial_config_validation() {
    local config_file_to_validate="$1"
    # Output variables, default to N/A or failure states
    local result_status="INVALID"
    local result_project_name="N/A"
    local result_backup_type="N/A"
    local failure_reason=""

    if [ ! -f "$config_file_to_validate" ]; then
        failure_reason="File not found: $config_file_to_validate"
        echo "${result_status}|${result_project_name}|${result_backup_type}|${failure_reason}"
        return 0
    fi

    # Source the config in a subshell to isolate environment and settings like set -u
    local validation_output
    validation_output=$(
        # Subshell environment
        set +u # Allow unset variables during sourcing for this check
        # shellcheck source=/dev/null
        source "$config_file_to_validate" # Source the configuration file

        # Capture values after sourcing, providing defaults if unset
        local current_project_name="${PROJECT_NAME:-}"
        local current_backup_type="${BACKUP_TYPE:-}"
        # Ensure DBS_TO_BACKUP is treated as an array, even if not properly defined in config
        local -a current_dbs_to_backup=()
        if declare -p DBS_TO_BACKUP 2>/dev/null | grep -q 'declare \-a'; then
             current_dbs_to_backup=("${DBS_TO_BACKUP[@]}")
        fi
        local current_db_user="${DB_USER:-}"
        local current_db_pass="${DB_PASSWORD:-}"
        # Default CLOUD_STORAGE_PROVIDER to "s3" for this check if it's involved
        local current_cloud_provider="${CLOUD_STORAGE_PROVIDER:-s3}"
        local current_s3_bucket="${S3_BUCKET_NAME:-}"
        local temp_failure_reason=""

        # Perform checks in order of importance
        if [ -z "$current_project_name" ]; then
            temp_failure_reason="PROJECT_NAME is not defined or is empty."
        # Check DBS_TO_BACKUP only if PROJECT_NAME is OK
        elif [ ${#current_dbs_to_backup[@]} -eq 0 ]; then
            # Allow DBS_TO_BACKUP to be empty if user intends to backup empty list (e.g. placeholder project)
            # but they still need DB_USER/PASS if any DBs were listed.
            # For basic validation, an empty DBS_TO_BACKUP will pass, but DB_USER/PASS are still checked if it's not empty.
            : # An empty DBS_TO_BACKUP array is not necessarily an error for basic validation
        # Check DB_USER/PASS only if DBS_TO_BACKUP is not empty
        elif [ ${#current_dbs_to_backup[@]} -gt 0 ]; then
            if [ -z "$current_db_user" ]; then temp_failure_reason="DB_USER is not defined (required as DBS_TO_BACKUP is not empty)."; fi
            if [ -z "$current_db_pass" ] && [ -z "$temp_failure_reason" ]; then temp_failure_reason="DB_PASSWORD is not defined (required as DBS_TO_BACKUP is not empty)."; fi
        fi

        # Check BACKUP_TYPE if previous checks passed
        if [ -z "$temp_failure_reason" ]; then
            if [ -z "$current_backup_type" ]; then
                temp_failure_reason="BACKUP_TYPE is not defined or is empty."
            elif [[ "$current_backup_type" != "local" && "$current_backup_type" != "cloud" && "$current_backup_type" != "both" ]]; then
                temp_failure_reason="Invalid BACKUP_TYPE: '$current_backup_type'. Allowed: local, cloud, both."
            # If backup type involves cloud and provider is S3, check S3 bucket
            elif [[ "$current_backup_type" == "cloud" || "$current_backup_type" == "both" ]]; then
                if [[ "$current_cloud_provider" == "s3" ]]; then # Assuming s3 is the focus
                    if [ -z "$current_s3_bucket" ]; then
                        temp_failure_reason="S3_BUCKET_NAME is not defined (required for S3 cloud backup)."
                    fi
                # No specific check for other cloud providers in this basic validation
                fi
            fi
        fi

        # Prepare output string based on validation outcome
        if [ -z "$temp_failure_reason" ]; then
            # If PROJECT_NAME was found, use it. Otherwise, it remains "N/A".
            # If BACKUP_TYPE was found and valid, use it. Otherwise, it remains "N/A".
            echo "VALID|${current_project_name:-N/A}|${current_backup_type:-N/A}"
        else
            echo "INVALID|${current_project_name:-N/A}|${current_backup_type:-N/A}|${temp_failure_reason}"
        fi
    ) # End of subshell

    # Echo the captured output from the subshell so the caller can get it
    echo "$validation_output"
    return 0 # The function perform_initial_config_validation itself completed successfully
}


# --- Internal Helper Variables ---
_PREFLIGHT_ERROR_FLAG=0 # 0 for no error, 1 for error

# =============================================================================
# FUNCTION: perform_global_preflight_checks
# Purpose: Performs one-time system-wide checks.
# To be called ONCE by the main frequency script AFTER root check.
# Output: Sets _PREFLIGHT_ERROR_FLAG to 1 on failure. Exits script if critical.
# =============================================================================
perform_global_preflight_checks() {
    _PREFLIGHT_ERROR_FLAG=0 # Reset error flag for this function call
    local prev_shell_opts_global_preflight ; prev_shell_opts_global_preflight="$-"

    echo ""
    echo "--- Starting Global Preflight Checks ---"

    # --- Check Global Dependencies (zip, bc, aws-cli, s3cmd) ---
    echo "[GLOBAL PREFLIGHT] Checking global dependencies..."
    local all_deps_ok=true

    # zip
    echo "[GLOBAL PREFLIGHT] Checking for zip..."
    if ! command -v zip &> /dev/null; then
        echo "[GLOBAL PREFLIGHT] zip not found. Attempting to install..."
        if "$PREFLIGHT_SCRIPT_DIR/dependencies/install_base_utils.sh" zip; then
            if ! command -v zip &> /dev/null; then echo "[GLOBAL PREFLIGHT ERROR] Failed to install zip." >&2; all_deps_ok=false; fi
        else echo "[GLOBAL PREFLIGHT ERROR] Base utils installer (for zip) failed." >&2; all_deps_ok=false; fi
    fi
    if command -v zip &> /dev/null; then echo "[GLOBAL PREFLIGHT] zip found."; else all_deps_ok=false; fi

    # bc
    echo "[GLOBAL PREFLIGHT] Checking for bc..."
    if ! command -v bc &> /dev/null; then
        echo "[GLOBAL PREFLIGHT] bc not found. Attempting to install..."
        if "$PREFLIGHT_SCRIPT_DIR/dependencies/install_base_utils.sh" bc; then
            if ! command -v bc &> /dev/null; then echo "[GLOBAL PREFLIGHT ERROR] Failed to install bc." >&2; all_deps_ok=false; fi
        else echo "[GLOBAL PREFLIGHT ERROR] Base utils installer (for bc) failed." >&2; all_deps_ok=false; fi
    fi
    if command -v bc &> /dev/null; then echo "[GLOBAL PREFLIGHT] bc found."; else all_deps_ok=false; fi

    # AWS CLI
    echo "[GLOBAL PREFLIGHT] Checking for AWS CLI..."
    if ! command -v aws &> /dev/null; then
        echo "[GLOBAL PREFLIGHT] AWS CLI not found. Attempting to install..."
        if ! "$PREFLIGHT_SCRIPT_DIR/dependencies/install_awscli_snap.sh"; then
            echo "[GLOBAL PREFLIGHT ERROR] AWS CLI installation script failed execution." >&2; all_deps_ok=false;
        elif ! command -v aws &> /dev/null; then echo "[GLOBAL PREFLIGHT ERROR] AWS CLI still not found after install attempt." >&2; all_deps_ok=false; fi
    fi
    if command -v aws &> /dev/null; then echo "[GLOBAL PREFLIGHT] AWS CLI found."; aws --version; else all_deps_ok=false; fi

    # s3cmd
    echo "[GLOBAL PREFLIGHT] Checking for s3cmd..."
    if ! command -v s3cmd &> /dev/null; then
        echo "[GLOBAL PREFLIGHT] s3cmd not found. Attempting to install..."
        if ! "$PREFLIGHT_SCRIPT_DIR/dependencies/install_s3cmd.sh"; then
            echo "[GLOBAL PREFLIGHT ERROR] s3cmd installation script failed execution." >&2; all_deps_ok=false;
        elif ! command -v s3cmd &> /dev/null; then echo "[GLOBAL PREFLIGHT ERROR] s3cmd still not found after install attempt." >&2; all_deps_ok=false; fi
    fi
    if command -v s3cmd &> /dev/null; then echo "[GLOBAL PREFLIGHT] s3cmd found."; else all_deps_ok=false; fi

    # sqlite3
    echo "[GLOBAL PREFLIGHT] Checking for sqlite3..."
    if ! command -v sqlite3 &> /dev/null; then
        echo "[GLOBAL PREFLIGHT] sqlite3 not found. Attempting to install..."
        if "$PREFLIGHT_SCRIPT_DIR/dependencies/install_base_utils.sh" sqlite3; then
            if ! command -v sqlite3 &> /dev/null; then echo "[GLOBAL PREFLIGHT ERROR] Failed to install sqlite3." >&2; all_deps_ok=false; fi
        else echo "[GLOBAL PREFLIGHT ERROR] Base utils installer (for sqlite3) failed." >&2; all_deps_ok=false; fi
    fi
    if command -v sqlite3 &> /dev/null; then echo "[GLOBAL PREFLIGHT] sqlite3 found."; else all_deps_ok=false; fi

    if ! $all_deps_ok; then
        echo "[GLOBAL PREFLIGHT FATAL] One or more critical global dependencies are missing or failed to install. Cannot continue." >&2
        _PREFLIGHT_ERROR_FLAG=1; if [[ "$prev_shell_opts_global_preflight" == *e* ]]; then exit 1; else return 1; fi
    fi
    echo "[GLOBAL PREFLIGHT] All global dependencies verified/installed."
    echo ""

    echo "[GLOBAL PREFLIGHT] Checking base system directories..."
    local base_log_dir="/var/log/db_backups"
    if [ ! -d "$base_log_dir" ]; then
        echo "[GLOBAL PREFLIGHT] Base log directory '$base_log_dir' does not exist. Attempting to create..."
        if ! mkdir -p "$base_log_dir"; then
            echo "[GLOBAL PREFLIGHT FATAL] Unable to create base log directory '$base_log_dir'. Cannot continue." >&2
            _PREFLIGHT_ERROR_FLAG=1; if [[ "$prev_shell_opts_global_preflight" == *e* ]]; then exit 1; else return 1; fi
        fi
        echo "[GLOBAL PREFLIGHT] Base log directory '$base_log_dir' created."
    else
        echo "[GLOBAL PREFLIGHT] Base log directory '$base_log_dir' exists."
    fi
    echo ""

    if [ $_PREFLIGHT_ERROR_FLAG -ne 0 ]; then
        echo "--- Global Preflight Checks FAILED ---" >&2
        if [[ "$prev_shell_opts_global_preflight" == *e* ]]; then exit 1; else return 1; fi
    fi

    echo "--- Global Preflight Checks Completed Successfully ---"
    return 0
}

# =============================================================================
# FUNCTION: perform_project_preflight_checks
# Purpose: Performs checks specific to a loaded project configuration.
# Assumes project config variables are loaded in the current environment.
# Output: Sets _PREFLIGHT_ERROR_FLAG to 1 on failure. Exits subshell on critical.
# =============================================================================
perform_project_preflight_checks() {
    _PREFLIGHT_ERROR_FLAG=0 # Reset for this function
    local prev_shell_opts_project_preflight ; prev_shell_opts_project_preflight="$-"

    # Temporarily disable exit on unset variables for initial config checks
    # The calling subshell should have sourced project config with `set +u` ideally.
    set +u

    echo ""
    echo "--- Starting Project-Specific Preflight Checks ---"
    echo "[PROJECT PREFLIGHT] Validating loaded configuration settings..."

    # PROJECT_NAME (Mandatory)
    if [ -z "${PROJECT_NAME+x}" ] || [ -z "$PROJECT_NAME" ]; then
        echo "[PROJECT PREFLIGHT ERROR] PROJECT_NAME is not defined or is empty. This is mandatory." >&2; _PREFLIGHT_ERROR_FLAG=1;
    else
        SANITIZED_PROJECT_NAME=$(echo "$PROJECT_NAME" | sed 's/[^a-zA-Z0-9_.-]/_/g' | sed 's/__*/_/g')
        if [ -z "$SANITIZED_PROJECT_NAME" ] || [[ "$SANITIZED_PROJECT_NAME" == "_" ]]; then
            echo "[PROJECT PREFLIGHT ERROR] PROJECT_NAME ('$PROJECT_NAME') is invalid after sanitization ('$SANITIZED_PROJECT_NAME'). Use alphanumeric, _, ., -." >&2; _PREFLIGHT_ERROR_FLAG=1;
        else
            echo "[PROJECT PREFLIGHT] PROJECT_NAME: '$PROJECT_NAME' (Sanitized: '$SANITIZED_PROJECT_NAME')."
        fi
    fi
    if [ $_PREFLIGHT_ERROR_FLAG -ne 0 ]; then if [[ "$prev_shell_opts_project_preflight" == *e* ]]; then exit 1; else return 1; fi; fi

    # LOCAL_BACKUP_ROOT (Derived if not set)
    USER_DEFINED_LBR="${LOCAL_BACKUP_ROOT:-}"
    if [ -z "$USER_DEFINED_LBR" ]; then
        LOCAL_BACKUP_ROOT="/var/backups/db_backups/$SANITIZED_PROJECT_NAME"
        echo "[PROJECT PREFLIGHT] LOCAL_BACKUP_ROOT not set by user, defaulting to: '$LOCAL_BACKUP_ROOT'."
    else
        LOCAL_BACKUP_ROOT="$USER_DEFINED_LBR"
        echo "[PROJECT PREFLIGHT] LOCAL_BACKUP_ROOT explicitly set by user: '$LOCAL_BACKUP_ROOT'."
    fi
    if [ -z "$LOCAL_BACKUP_ROOT" ]; then echo "[PROJECT PREFLIGHT ERROR] LOCAL_BACKUP_ROOT is empty." >&2; _PREFLIGHT_ERROR_FLAG=1; fi
    if [ $_PREFLIGHT_ERROR_FLAG -ne 0 ]; then if [[ "$prev_shell_opts_project_preflight" == *e* ]]; then exit 1; else return 1; fi; fi

    # TEMP_DIR (Derived if not set)
    USER_DEFINED_TD="${TEMP_DIR:-}"
    if [ -z "$USER_DEFINED_TD" ]; then
        TEMP_DIR="/var/cache/db_backups/${SANITIZED_PROJECT_NAME}_temp"
        echo "[PROJECT PREFLIGHT] TEMP_DIR not set by user, defaulting to: '$TEMP_DIR'."
    else
        TEMP_DIR="$USER_DEFINED_TD"
        echo "[PROJECT PREFLIGHT] TEMP_DIR explicitly set by user: '$TEMP_DIR'."
    fi
    if [ -z "$TEMP_DIR" ]; then echo "[PROJECT PREFLIGHT ERROR] TEMP_DIR is empty." >&2; _PREFLIGHT_ERROR_FLAG=1; fi
    if [ $_PREFLIGHT_ERROR_FLAG -ne 0 ]; then if [[ "$prev_shell_opts_project_preflight" == *e* ]]; then exit 1; else return 1; fi; fi
    echo "[PROJECT PREFLIGHT] Final Paths: LOCAL_BACKUP_ROOT='$LOCAL_BACKUP_ROOT', TEMP_DIR='$TEMP_DIR'."

    # BACKUP_TYPE
    DEFAULT_BACKUP_TYPE="cloud"
    if [ -z "${BACKUP_TYPE+x}" ] || [ -z "$BACKUP_TYPE" ]; then BACKUP_TYPE="$DEFAULT_BACKUP_TYPE"; echo "[PROJECT PREFLIGHT] BACKUP_TYPE not set, defaulting to '$BACKUP_TYPE'."; fi
    echo "[PROJECT PREFLIGHT] BACKUP_TYPE: '$BACKUP_TYPE'."

    # DB_TYPE
    DEFAULT_DB_TYPE="mysql"
    if [ -z "${DB_TYPE+x}" ] || [ -z "$DB_TYPE" ]; then DB_TYPE="$DEFAULT_DB_TYPE"; echo "[PROJECT PREFLIGHT] DB_TYPE not set, defaulting to '$DB_TYPE'."; fi
    echo "[PROJECT PREFLIGHT] DB_TYPE: '$DB_TYPE'."

    # DBS_TO_BACKUP
    if ! declare -p DBS_TO_BACKUP 2>/dev/null | grep -q 'declare \-a' || [ ${#DBS_TO_BACKUP[@]} -eq 0 ]; then
        echo "[PROJECT PREFLIGHT ERROR] DBS_TO_BACKUP is not a non-empty array." >&2; _PREFLIGHT_ERROR_FLAG=1;
    else echo "[PROJECT PREFLIGHT] DBS_TO_BACKUP: (${DBS_TO_BACKUP[*]})."; fi
    if [ $_PREFLIGHT_ERROR_FLAG -ne 0 ]; then if [[ "$prev_shell_opts_project_preflight" == *e* ]]; then exit 1; else return 1; fi; fi

    # DB_USER, DB_PASSWORD
    if [ ${#DBS_TO_BACKUP[@]} -gt 0 ]; then
        if [ -z "${DB_USER+x}" ] || [ -z "$DB_USER" ]; then echo "[PROJECT PREFLIGHT ERROR] DB_USER not set." >&2; _PREFLIGHT_ERROR_FLAG=1; fi
        if [ -z "${DB_PASSWORD+x}" ] || [ -z "$DB_PASSWORD" ]; then echo "[PROJECT PREFLIGHT ERROR] DB_PASSWORD not set." >&2; _PREFLIGHT_ERROR_FLAG=1; fi
        if [ $_PREFLIGHT_ERROR_FLAG -eq 0 ]; then echo "[PROJECT PREFLIGHT] DB credentials (USER/PASS) present."; fi
    fi
    if [ $_PREFLIGHT_ERROR_FLAG -ne 0 ]; then if [[ "$prev_shell_opts_project_preflight" == *e* ]]; then exit 1; else return 1; fi; fi

    # CLOUD_STORAGE_PROVIDER, S3_BUCKET_NAME
    if [[ "$BACKUP_TYPE" == "cloud" || "$BACKUP_TYPE" == "both" ]]; then
        DEFAULT_CSP="s3"; if [ -z "${CLOUD_STORAGE_PROVIDER+x}" ] || [ -z "$CLOUD_STORAGE_PROVIDER" ]; then CLOUD_STORAGE_PROVIDER="$DEFAULT_CSP"; echo "[PROJECT PREFLIGHT] CLOUD_STORAGE_PROVIDER not set, defaulting to '$CLOUD_STORAGE_PROVIDER'."; fi
        echo "[PROJECT PREFLIGHT] CLOUD_STORAGE_PROVIDER: '$CLOUD_STORAGE_PROVIDER'."
        if [[ "$CLOUD_STORAGE_PROVIDER" == "s3" ]]; then
            if [ -z "${S3_BUCKET_NAME+x}" ] || [ -z "$S3_BUCKET_NAME" ]; then echo "[PROJECT PREFLIGHT ERROR] S3_BUCKET_NAME not set for S3 cloud backup." >&2; _PREFLIGHT_ERROR_FLAG=1;
            else echo "[PROJECT PREFLIGHT] S3_BUCKET_NAME: '$S3_BUCKET_NAME'."; fi
        elif [ -n "$CLOUD_STORAGE_PROVIDER" ]; then echo "[PROJECT PREFLIGHT WARN] CLOUD_STORAGE_PROVIDER '$CLOUD_STORAGE_PROVIDER' is not 's3'." >&2; fi
    fi
    if [ $_PREFLIGHT_ERROR_FLAG -ne 0 ]; then if [[ "$prev_shell_opts_project_preflight" == *e* ]]; then exit 1; else return 1; fi; fi

    # Enable strict mode for remaining checks
    set -u

    # S3_FULL_PATH Construction (now that S3_BUCKET_NAME is validated if needed)
    S3_FULL_PATH=""
    if [[ "$BACKUP_TYPE" == "cloud" || "$BACKUP_TYPE" == "both" ]] && [[ "$CLOUD_STORAGE_PROVIDER" == "s3" ]] && [ -n "$S3_BUCKET_NAME" ]; then
        if [ -n "${S3_PATH+x}" ] && [ -n "$S3_PATH" ]; then
            S3_BUCKET_CLEAN=${S3_BUCKET_NAME%/}
            S3_PATH_CLEAN=${S3_PATH#/}
            S3_PATH_CLEAN=${S3_PATH_CLEAN%/}
            S3_FULL_PATH="s3://${S3_BUCKET_CLEAN}/${S3_PATH_CLEAN}"
        else S3_FULL_PATH="s3://${S3_BUCKET_NAME%/}"; fi
        echo "[PROJECT PREFLIGHT] S3 Base Path: '$S3_FULL_PATH'."
    fi

    # Final value validations for BACKUP_TYPE, DB_TYPE
    if [[ "$BACKUP_TYPE" != "local" && "$BACKUP_TYPE" != "cloud" && "$BACKUP_TYPE" != "both" ]]; then echo "[PROJECT PREFLIGHT ERROR] Invalid BACKUP_TYPE: '$BACKUP_TYPE'." >&2; _PREFLIGHT_ERROR_FLAG=1; fi
    if [[ "$DB_TYPE" != "mysql" && "$DB_TYPE" != "mariadb" && "$DB_TYPE" != "postgres" && "$DB_TYPE" != "mongodb" ]]; then echo "[PROJECT PREFLIGHT ERROR] Invalid DB_TYPE: '$DB_TYPE'." >&2; _PREFLIGHT_ERROR_FLAG=1; fi
    if [[ "$DB_TYPE" == "postgres" || "$DB_TYPE" == "mongodb" ]]; then echo "[PROJECT PREFLIGHT WARN] DB_TYPE '$DB_TYPE' support is experimental." >&2; fi
    if [ $_PREFLIGHT_ERROR_FLAG -ne 0 ]; then if [[ "$prev_shell_opts_project_preflight" == *e* ]]; then exit 1; else return 1; fi; fi

    # Create project-specific directories
    echo "[PROJECT PREFLIGHT] Checking/Creating project directories..."
    for dir_to_check in "$LOCAL_BACKUP_ROOT" "$TEMP_DIR"; do
        echo "[PROJECT PREFLIGHT]  Path: '$dir_to_check'"
        if [ ! -d "$dir_to_check" ]; then
            echo "[PROJECT PREFLIGHT]  Directory '$dir_to_check' does not exist. Creating..."
            if ! mkdir -p "$dir_to_check"; then echo "[PROJECT PREFLIGHT CRITICAL] Unable to create '$dir_to_check'." >&2; _PREFLIGHT_ERROR_FLAG=1; break; fi
            echo "[PROJECT PREFLIGHT]  '$dir_to_check' created."
        else echo "[PROJECT PREFLIGHT]  '$dir_to_check' exists."; fi
    done
    if [ $_PREFLIGHT_ERROR_FLAG -ne 0 ]; then if [[ "$prev_shell_opts_project_preflight" == *e* ]]; then exit 1; else return 1; fi; fi
    echo ""

    # S3 Path Accessibility & AWS/s3cmd config check
    if [[ "$BACKUP_TYPE" == "cloud" || "$BACKUP_TYPE" == "both" ]] && [[ "$CLOUD_STORAGE_PROVIDER" == "s3" ]] && [ -n "$S3_FULL_PATH" ]; then
        s3_path_no_protocol=${S3_FULL_PATH#s3://}; s3_target_bucket=${s3_path_no_protocol%%/*}; s3_target_prefix=${s3_path_no_protocol#*/}
        if [[ "$s3_target_prefix" == "$s3_target_bucket" ]]; then s3_target_prefix=""; fi
        if [ -n "$s3_target_prefix" ] && [ "$s3_target_prefix" != "/" ] && [[ "${s3_target_prefix: -1}" != "/" ]]; then s3_target_prefix="${s3_target_prefix}/"; fi
        if [ "$s3_target_prefix" == "/" ]; then s3_target_prefix=""; fi
        local s3_check_path="s3://${s3_target_bucket}/${s3_target_prefix}"
        echo "[PROJECT PREFLIGHT] Checking S3 path: ${s3_check_path}"

        # Basic AWS CLI & s3cmd configuration check (tools must be configured to operate)
        # These strict checks attempt a listing, which is a good test.
        local s3_tools_configured=true
        if ! "$PREFLIGHT_SCRIPT_DIR/dependencies/check_awscli_config_strict.sh"; then echo "[PROJECT PREFLIGHT WARN] AWS CLI strict config check failed." >&2; s3_tools_configured=false; fi
        if ! "$PREFLIGHT_SCRIPT_DIR/dependencies/check_s3cmd_config_strict.sh"; then echo "[PROJECT PREFLIGHT WARN] s3cmd strict config check failed." >&2; s3_tools_configured=false; fi
        if ! $s3_tools_configured; then echo "[PROJECT PREFLIGHT ERROR] AWS CLI or s3cmd not sufficiently configured for S3 ops. Run 'aws configure' / 's3cmd --configure'." >&2; _PREFLIGHT_ERROR_FLAG=1; fi

        if [ $_PREFLIGHT_ERROR_FLAG -eq 0 ]; then # Only proceed if tools seem configured
            if aws s3 ls "${s3_check_path}" >/dev/null 2>&1; then echo "[PROJECT PREFLIGHT] S3 path '${s3_check_path}' accessible."
            else
                echo "[PROJECT PREFLIGHT WARN] S3 path '${s3_check_path}' not accessible or non-existent." >&2
                if [ -n "$s3_target_prefix" ]; then
                    echo "[PROJECT PREFLIGHT] Attempting to create S3 'folder': $s3_target_prefix in bucket $s3_target_bucket"
                    if ! aws s3api put-object --bucket "$s3_target_bucket" --key "$s3_target_prefix" >/dev/null 2>&1; then
                         echo "[PROJECT PREFLIGHT ERROR] Failed to create S3 folder path: ${s3_check_path}" >&2; _PREFLIGHT_ERROR_FLAG=1;
                    else echo "[PROJECT PREFLIGHT] Successfully created S3 folder: ${s3_check_path}"; fi
                else echo "[PROJECT PREFLIGHT ERROR] S3 path is bucket root but bucket not accessible/extant." >&2; _PREFLIGHT_ERROR_FLAG=1; fi
            fi
        fi
        echo ""
    fi
    if [ $_PREFLIGHT_ERROR_FLAG -ne 0 ]; then if [[ "$prev_shell_opts_project_preflight" == *e* ]]; then exit 1; else return 1; fi; fi

    # TTL Validation
    echo "[PROJECT PREFLIGHT] Validating TTLs..."
    # shellcheck source=lib/ttl_parser.sh
    source "$PREFLIGHT_SCRIPT_DIR/lib/ttl_parser.sh" || { echo "[PROJECT PREFLIGHT CRITICAL] Cannot source ttl_parser.sh" >&2; _PREFLIGHT_ERROR_FLAG=1; }
    if [ $_PREFLIGHT_ERROR_FLAG -eq 0 ]; then
        TTL_VARS=("TTL_MINUTELY_BACKUP" "TTL_HOURLY_BACKUP" "TTL_DAILY_BACKUP" "TTL_WEEKLY_BACKUP" "TTL_MONTHLY_BACKUP" "TTL_YEARLY_BACKUP")
        valid_ttls=true
        for var_name in "${TTL_VARS[@]}"; do
            human_ttl_value=""; if [ -n "${!var_name+x}" ]; then human_ttl_value="${!var_name}"; fi
            if [ -z "$human_ttl_value" ]; then declare "$var_name=0"; echo "[PROJECT PREFLIGHT] TTL '$var_name' not set, default 0 mins."; continue; fi
            if [[ "$human_ttl_value" =~ ^0[mMhHdDwWyY]?$ || "$human_ttl_value" == "0" ]]; then declare "$var_name=0"; echo "[PROJECT PREFLIGHT] TTL '$var_name' is '$human_ttl_value' (0 mins)."; continue; fi
            parsed_minutes=$(parse_human_ttl_to_minutes "$human_ttl_value")
            if [[ "$parsed_minutes" == "INVALID_TTL" ]] || ! [[ "$parsed_minutes" =~ ^[0-9]+$ ]]; then echo "[PROJECT PREFLIGHT ERROR] Invalid TTL for '$var_name': '$human_ttl_value'." >&2; valid_ttls=false;
            else echo "[PROJECT PREFLIGHT] TTL '$var_name': '$human_ttl_value' ($parsed_minutes mins)."; declare "$var_name=$parsed_minutes"; fi
        done
        if ! $valid_ttls; then echo "[PROJECT PREFLIGHT ERROR] Invalid TTLs found." >&2; _PREFLIGHT_ERROR_FLAG=1; else echo "[PROJECT PREFLIGHT] TTLs validated."; fi
    fi
    echo ""
    if [ $_PREFLIGHT_ERROR_FLAG -ne 0 ]; then if [[ "$prev_shell_opts_project_preflight" == *e* ]]; then exit 1; else return 1; fi; fi

    echo "--- Project-Specific Preflight Checks Completed Successfully ---"
    # Restore original shell options that were active when this function was called
    if [[ "$prev_shell_opts_project_preflight" == *u* ]]; then set -u; else set +u; fi
    if [[ "$prev_shell_opts_project_preflight" == *e* ]]; then set -e; else set +e; fi
    return 0
}

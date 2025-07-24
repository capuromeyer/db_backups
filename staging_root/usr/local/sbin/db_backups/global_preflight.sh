#!/bin/bash
# =============================================================================
# Script: global_preflight.sh
# Purpose: Performs pre-run checks and setup for the db_backups scripts. It provides
#          functions for global (one-time) checks, including dependency
#          verification and installation, and cloud CLI configuration checks.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.154800
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: This script is intended to be sourced by other scripts. The main entry
#        point is the `run_all_preflight_checks` function.
#
# Notes:
# - This script defines functions for global checks only.
# - The calling script should perform a root check before sourcing this script.
# =============================================================================

# PREFLIGHT_SCRIPT_DIR is set to the directory of this script itself.
PREFLIGHT_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# --- Global Error Flag ---
# _PREFLIGHT_GLOBAL_ERROR_FLAG is used internally to track overall errors
# across multiple preflight checks.
_PREFLIGHT_GLOBAL_ERROR_FLAG=0

# =============================================================================
# INTERNAL HELPER FUNCTIONS
# These functions are designed to be called internally by the main preflight
# functions and are not typically exposed for direct external use.
# =============================================================================

# -----------------------------------------------------------------------------
# Function: _log_message
# Purpose: Standardized logging helper.
# Arguments: $1 - Log level (INFO, WARN, ERROR, FATAL)
#            $2 - Message to log
# -----------------------------------------------------------------------------
_log_message() {
    local level="$1"
    local message="$2"
    case "$level" in
        INFO)    echo "[PREFLIGHT] INFO $message" ;;
        WARN)    echo "[PREFLIGHT] WARN $message" >&2 ;;
        ERROR)   echo "[PREFLIGHT] ERROR $message" >&2 ;;
        FATAL)   echo "[PREFLIGHT] FATAL $message" >&2 ;;
        *)       echo "[PREFLIGHT] UNKNOWN $message" >&2 ;; # Fallback for unknown levels
    esac
}

# -----------------------------------------------------------------------------
# Function: _check_command_exists
# Purpose: Checks if a given command exists in the system's PATH.
# Arguments: $1 - The command name to check.
# Returns: 0 if command exists, 1 otherwise.
# -----------------------------------------------------------------------------
_check_command_exists() {
    local cmd="$1"
    command -v "$cmd" &> /dev/null
    return $?
}

# -----------------------------------------------------------------------------
# Function: _attempt_dependency_install
# Purpose: Executes an installation script for a given dependency.
# Arguments: $1 - The name of the dependency.
#            $2 - The installation script path relative to PREFLIGHT_SCRIPT_DIR/dependencies.
# Returns: 0 on successful installation script execution, 1 on failure.
# -----------------------------------------------------------------------------
_attempt_dependency_install() {
    local dep_name="$1"
    local install_script="$2"
    local full_install_script_path="$PREFLIGHT_SCRIPT_DIR/dependencies/$install_script"

    _log_message INFO "Attempting to install $dep_name using $full_install_script_path..."
    if [ ! -f "$full_install_script_path" ]; then
        _log_message ERROR "Installation script '$install_script' not found for $dep_name."
        return 1
    fi

    # Execute the installation script. Pass dep_name as an argument if the script expects it.
    if "$full_install_script_path" "$dep_name"; then
        _log_message INFO "Installation script for $dep_name executed successfully."
        return 0
    else
        _log_message ERROR "Installation script for $dep_name failed."
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Function: _verify_and_install_dependency
# Purpose: Checks for a dependency, attempts to install it if missing,
#          and then re-checks its presence.
# Arguments: $1 - The name of the dependency (e.g., "zip", "aws").
#            $2 - The installation script relative path (e.g., "install_base_utils.sh").
# Returns: 0 if dependency is found/installed, 1 otherwise.
# -----------------------------------------------------------------------------
_verify_and_install_dependency() {
    local dep_name="$1"
    local install_script="$2"

    _log_message INFO "Checking for $dep_name..."
    if ! _check_command_exists "$dep_name"; then
        _log_message WARN "$dep_name not found. Attempting to install..."
        if _attempt_dependency_install "$dep_name" "$install_script"; then
            if ! _check_command_exists "$dep_name"; then
                _log_message ERROR "Failed to install $dep_name, or it's not in PATH after installation."
                return 1
            fi
        else
            _log_message ERROR "Installation process for $dep_name failed."
            return 1
        fi
    fi

    if _check_command_exists "$dep_name"; then
        _log_message INFO "$dep_name found."
        if [ "$dep_name" == "aws" ]; then
            aws --version # Show AWS CLI version for verification
        fi
        return 0
    else
        return 1 # Should not happen if logic above is correct, but for safety
    fi
}

# =============================================================================
# GLOBAL PREFLIGHT CHECK FUNCTIONS
# These functions perform specific global system checks.
# =============================================================================

# -----------------------------------------------------------------------------
# Function: _check_global_base_dependencies
# Purpose: Verifies the presence and optionally installs critical system
#          dependencies like zip, bc, and sqlite3.
# Returns: 0 if all dependencies are present/installed, 1 otherwise.
# -----------------------------------------------------------------------------
_check_global_base_dependencies() {
    _log_message INFO "Checking global base dependencies (zip, bc, sqlite3)..."
    local all_deps_ok=true

    _verify_and_install_dependency "zip" "install_base_utils.sh" || all_deps_ok=false
    _verify_and_install_dependency "bc" "install_base_utils.sh" || all_deps_ok=false
    _verify_and_install_dependency "sqlite3" "install_base_utils.sh" || all_deps_ok=false

    if ! $all_deps_ok; then
        _log_message FATAL "One or more critical global base dependencies are missing or failed to install."
        return 1
    fi
    _log_message INFO "All global base dependencies verified/installed."
    return 0
}

# -----------------------------------------------------------------------------
# Function: _check_and_install_aws_cli_binary
# Purpose: Checks if AWS CLI is installed and attempts to install it if missing.
# Returns: 0 if AWS CLI binary is found/installed, 1 otherwise.
# -----------------------------------------------------------------------------
_check_and_install_aws_cli_binary() {
    _log_message INFO "Checking and installing AWS CLI binary..."
    if _verify_and_install_dependency "aws" "install_awscli_snap.sh"; then
        _log_message INFO "AWS CLI binary found/installed."
        return 0
    else
        _log_message ERROR "AWS CLI binary not found or failed to install."
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Function: _check_and_install_s3cmd_binary
# Purpose: Checks if s3cmd is installed and attempts to install it if missing.
# Returns: 0 if s3cmd binary is found/installed, 1 otherwise.
# -----------------------------------------------------------------------------
_check_and_install_s3cmd_binary() {
    _log_message INFO "Checking and installing s3cmd binary..."
    if _verify_and_install_dependency "s3cmd" "install_s3cmd.sh"; then
        _log_message INFO "s3cmd binary found/installed."
        return 0
    else
        _log_message ERROR "s3cmd binary not found or failed to install."
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Function: check_aws_cli_configuration
# Purpose: Verifies the configuration of AWS CLI.
# Returns: 0 if AWS CLI is sufficiently configured, 1 otherwise.
# -----------------------------------------------------------------------------
check_aws_cli_configuration() {
    _log_message INFO "Verifying AWS CLI configuration..."
    if _check_command_exists "aws"; then
        if ! "$PREFLIGHT_SCRIPT_DIR/dependencies/check_awscli_config_strict.sh"; then
            _log_message ERROR "AWS CLI is installed but not sufficiently configured. Run 'aws configure'."
            return 1
        else
            _log_message INFO "AWS CLI configuration verified."
            return 0
        fi
    else
        _log_message WARN "AWS CLI not found, skipping configuration check."
        return 1 # Consider it a failure for configuration if binary isn't there
    fi
}

# -----------------------------------------------------------------------------
# Function: check_s3cmd_configuration
# Purpose: Verifies the configuration of s3cmd.
# Returns: 0 if s3cmd is sufficiently configured, 1 otherwise.
# -----------------------------------------------------------------------------
check_s3cmd_configuration() {
    _log_message INFO "Verifying s3cmd configuration..."
    if _check_command_exists "s3cmd"; then
        if ! "$PREFLIGHT_SCRIPT_DIR/dependencies/check_s3cmd_config_strict.sh"; then
            _log_message ERROR "s3cmd is installed but not sufficiently configured. Run 's3cmd --configure'."
            return 1
        else
            _log_message INFO "s3cmd configuration verified."
            return 0
        fi
    else
        _log_message WARN "s3cmd not found, skipping configuration check."
        return 1 # Consider it a failure for configuration if binary isn't there
    fi
}

# -----------------------------------------------------------------------------
# Function: _ensure_base_log_directory
# Purpose: Checks if the base log directory exists and attempts to create it
#          if it doesn't.
# Returns: 0 on success, 1 on failure.
# -----------------------------------------------------------------------------
_ensure_base_log_directory() {
    local base_log_dir="/var/log/db_backups"
    _log_message INFO "Checking base system directories..."

    if [ ! -d "$base_log_dir" ]; then
        _log_message INFO "Base log directory '$base_log_dir' does not exist. Attempting to create..."
        if ! mkdir -p "$base_log_dir"; then
            _log_message FATAL "Unable to create base log directory '$base_log_dir'. Cannot continue."
            return 1
        fi
        _log_message INFO "Base log directory '$base_log_dir' created."
    else
        _log_message INFO "Base log directory '$base_log_dir' exists."
    fi
    return 0
}

# =============================================================================
# MAIN PREFLIGHT FUNCTIONS
# These functions orchestrate the internal checks.
# =============================================================================

# -----------------------------------------------------------------------------
# FUNCTION: perform_global_preflight_checks
# Purpose: Performs one-time system-wide checks.
# To be called ONCE by the main frequency script AFTER root check.
# Output: Sets _PREFLIGHT_GLOBAL_ERROR_FLAG to 1 on failure. Exits script if critical.
# -----------------------------------------------------------------------------
perform_global_preflight_checks() {
    _PREFLIGHT_GLOBAL_ERROR_FLAG=0 # Reset error flag for this function call
    local prev_shell_opts_global_preflight ; prev_shell_opts_global_preflight="$-"

    echo ""
    _log_message INFO "--- Starting Global Preflight Checks ---"

    # Run individual global checks
    _check_global_base_dependencies || _PREFLIGHT_GLOBAL_ERROR_FLAG=1
    echo "" # Add a newline for better readability between sections

    _check_and_install_aws_cli_binary || _PREFLIGHT_GLOBAL_ERROR_FLAG=1
    echo ""

    _check_and_install_s3cmd_binary || _PREFLIGHT_GLOBAL_ERROR_FLAG=1
    echo ""

    _ensure_base_log_directory || _PREFLIGHT_GLOBAL_ERROR_FLAG=1
    echo ""

    if [ $_PREFLIGHT_GLOBAL_ERROR_FLAG -ne 0 ]; then
        _log_message FATAL "--- Global Preflight Checks FAILED ---"
        # Preserve original exit/return behavior based on shell options
        if [[ "$prev_shell_opts_global_preflight" == *e* ]]; then exit 1; else return 1; fi
    fi

    _log_message INFO "--- Global Preflight Checks Completed Successfully ---"
    return 0
}

# =============================================================================
# ORCHESTRATOR FUNCTION
# This function calls all necessary preflight checks in a logical order.
# =============================================================================

# -----------------------------------------------------------------------------
# FUNCTION: run_all_preflight_checks
# Purpose: Orchestrates all GLOBAL preflight checks, providing verbose output.
# To be called by the main script to perform all necessary setup and checks.
# Arguments: None (This function now focuses solely on global checks)
# Returns: 0 if all global checks pass, 1 if any critical check fails.
# -----------------------------------------------------------------------------
run_all_preflight_checks() {
    _PREFLIGHT_GLOBAL_ERROR_FLAG=0 # Reset overall error flag
    local overall_status=0

    echo "_______________________________________________________________________________"
    echo ""
    echo "----------------------------------------------------------------"
    echo " PREFLIGHT - Starting Comprehensive Global Preflight Check"
    echo "----------------------------------------------------------------"
    echo ""

    # Step 1: Perform Global Preflight Checks (includes binary installation for S3 tools)
    echo "[PREFLIGHT] STEP 1/1: Initiating global system dependencies checks ..."
    if ! perform_global_preflight_checks; then
        _log_message FATAL "Global preflight checks failed. Aborting."
        overall_status=1
    else
        _log_message INFO "Global preflight checks completed successfully."
    fi
    echo ""

    if [ "$overall_status" -eq 0 ]; then
        _log_message INFO "All Global Preflight checks completed successfully."
    else
        _log_message FATAL "One or more global preflight checks failed. Please review logs above."
    fi
    echo ""
    echo "----------------------------------------------------------------"
    echo " PREFLIGHT - Global Preflight Check Ends"
    echo "----------------------------------------------------------------"

    echo ""

    return "$overall_status"
}

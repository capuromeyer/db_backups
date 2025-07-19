#!/bin/bash
# -----------------------------------------------------------------------------
# Script: run_backup.sh
# Purpose: Provides a master entry point to trigger backups for a specific
#          frequency via a command-line argument.
# Developed by: Alejandro Capuro (Project Lead & Logic Design)
# Implemented by: Jules (AI Assistant, under guidance)
# Copyright: (c) 2025 Alejandro Capuro. All rights reserved.
# File Version: 20250702.190000 # YYYYMMDD.HHMMSS
# Project Version: 1.0.0
#
# Usage:
#   sudo /usr/local/sbin/db_backups/run_backup.sh --frequency <type>
#   <type> can be: minutely, hourly, daily, weekly, monthly
#
# Notes:
#   - Sources preflight.sh and lib/backup_orchestrator.sh.
#   - Maps frequency type to appropriate global directory and TTL variable names.
# -----------------------------------------------------------------------------

set -e # Exit immediately if a command exits with a non-zero status.

CURRENT_CONTEXT_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# --- Helper: Usage Function ---
usage() {
    echo "Usage: $0 --frequency <type>"
    echo ""
    echo "  This script initiates a backup cycle for the specified frequency."
    echo "  It centralizes backup operations, controlled by arguments."
    echo ""
    echo "  <type> must be one of:"
    echo "    minutely"
    echo "    hourly"
    echo "    daily"
    echo "    weekly"
    echo "    monthly"
    echo ""
    echo "Example:"
    echo "  sudo $0 --frequency daily"
    echo ""
    exit 1
}

# --- Argument Parsing ---
frequency_arg=""

# Check if any arguments are provided
if [ $# -eq 0 ]; then
    echo "[RUN_BACKUP_ERROR] No arguments provided." >&2
    usage
fi

if [ "$1" == "--frequency" ]; then
    if [ -n "$2" ]; then
        frequency_arg="$2"
        shift 2 # Consume --frequency and its value
    else
        echo "[RUN_BACKUP_ERROR] --frequency parameter requires a value (e.g., 'daily')." >&2
        usage
    fi
else
    echo "[RUN_BACKUP_ERROR] Unrecognized or missing --frequency parameter." >&2
    usage
fi

# Check for any other unexpected arguments
if [ $# -ne 0 ]; then
    echo "[RUN_BACKUP_ERROR] Unexpected arguments provided after --frequency <value>: '$*'" >&2
    usage
fi

# --- Source Preflight & Orchestrator ---
# shellcheck source=preflight.sh
source "$CURRENT_CONTEXT_SCRIPT_DIR/preflight.sh" || {
    echo "[RUN_BACKUP_FATAL] Unable to source preflight.sh. Exiting." >&2
    exit 1
}

# SCRIPT_DIR is now globally available from preflight.sh
# shellcheck source=lib/backup_orchestrator.sh
source "$SCRIPT_DIR/lib/backup_orchestrator.sh" || {
    echo "[RUN_BACKUP_FATAL] Unable to source lib/backup_orchestrator.sh. Exiting." >&2
    exit 1
}

# --- Map Frequency Argument to Variables ---
local_dir_varname=""
ttl_varname=""

case "$frequency_arg" in
    minutely)
        local_dir_varname="MINUTE_BACKUP_DIRECTORY"
        ttl_varname="TTL_MINUTELY_BACKUP"
        ;;
    hourly)
        local_dir_varname="HOURLY_BACKUP_DIRECTORY"
        ttl_varname="TTL_HOURLY_BACKUP"
        ;;
    daily)
        local_dir_varname="DAILY_BACKUP_DIRECTORY"
        ttl_varname="TTL_DAILY_BACKUP"
        ;;
    weekly)
        local_dir_varname="WEEKLY_BACKUP_DIRECTORY"
        ttl_varname="TTL_WEEKLY_BACKUP"
        ;;
    monthly)
        local_dir_varname="MONTHLY_BACKUP_DIRECTORY"
        ttl_varname="TTL_MONTHLY_BACKUP"
        ;;
    *)
        echo "[RUN_BACKUP_ERROR] Invalid value for --frequency: '$frequency_arg'." >&2
        usage # Will exit and display valid options
        ;;
esac

echo "///////////////////////////////////////////////////////////////////////////////"
echo "RUN_BACKUP Script started for '$frequency_arg' frequency at | $(date)"
echo "///////////////////////////////////////////////////////////////////////////////"

# --- Execute Backup Cycle ---
execute_backup_cycle "$frequency_arg" "$local_dir_varname" "$ttl_varname"
exit_status=$?

if [ $exit_status -eq 0 ]; then
    echo "[RUN_BACKUP_INFO] '$frequency_arg' backup cycle completed successfully."
else
    echo "[RUN_BACKUP_ERROR] '$frequency_arg' backup cycle failed with exit code $exit_status." >&2
fi

echo "///////////////////////////////////////////////////////////////////////////////"
echo "RUN_BACKUP Script for '$frequency_arg' frequency finished at | $(date)"
echo "///////////////////////////////////////////////////////////////////////////////"
echo ""

exit $exit_status

#!/bin/bash
# =============================================================================
# Script: dbb-minutely.sh
# Purpose: A wrapper script designed to be executed by a minutely cron job.
#          Its main function is to invoke the global-runner.sh script,
#          passing 'minutely' as the specific backup frequency.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.153600
# Project Version: 1.0.0
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: This script is intended for use by a scheduler (like cron) and is not
#        meant for direct execution with arguments.
#
# Notes:
# - This script acts as a simple, frequency-specific trigger for the main
#   backup orchestration script.
# =============================================================================

# Define the frequency for this specific wrapper script
FREQUENCY="minutely"

# Define the path to the global runner script
GLOBAL_RUNNER_SCRIPT="/usr/local/sbin/db_backups/global-runner.sh"

# --- Basic Root Check for the wrapper itself (optional, but good practice) ---
# If this script is executed directly by a non-root user, this will prompt for sudo.
# If run by cron as root, this check is redundant but harmless.
if [[ $EUID -ne 0 ]]; then
    echo "This wrapper script must be run as root. Please use sudo."
    exit 1
fi

# Call the global-runner.sh script with the specified frequency
# The 'sudo' here is for clarity, as cron typically runs as root.
# If this wrapper is called by a non-root user, it ensures global-runner.sh runs as root.
sudo "$GLOBAL_RUNNER_SCRIPT" "$FREQUENCY"

# Capture the exit status of the global-runner.sh
EXIT_STATUS=$?

if [ $EXIT_STATUS -eq 0 ]; then
    echo ""
    echo "//////////////////////////////////////////////////////////////////////////////////////"
    echo "Backup Grapper Process for $FREQUENCY frequency completed."
    echo "______________________________________________________________________________________"
    echo ""
else
    echo ""
    echo "//////////////////////////////////////////////////////////////////////////////////////"
    echo "Backup Grapper Process for $FREQUENCY frequency failed. Please check logs for details."
    echo "______________________________________________________________________________________"
    echo ""
fi

exit $EXIT_STATUS

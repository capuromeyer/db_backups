#!/bin/bash
# -----------------------------------------------------------------------------
# Script:  dbb-monthly.sh
# Purpose: Wrapper script for the hourly cronjob.
#          Calls the global-runner.sh with 'monthly' frequency.
# -----------------------------------------------------------------------------

# Define the frequency for this specific wrapper script
FREQUENCY="monthly"

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

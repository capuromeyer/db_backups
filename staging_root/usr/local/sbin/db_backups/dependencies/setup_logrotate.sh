#!/bin/bash
# -----------------------------------------------------------------------------
# Script: setup_logrotate.sh
# Purpose: Sets up logrotate configuration for the db_backups tool.
#          Creates a config file in /etc/logrotate.d/ to manage backup script logs.
# Author: Alejandro Capuro (Original tool concept) / Jules (Script generation)
# Copyright: (c) $(date +%Y) Alejandro Capuro. All rights reserved.
# Version: 0.1.0
#
# Notes:
#   - Requires sudo to write to /etc/logrotate.d/.
#   - Ensures the log directory /var/log/db_backups exists.
# -----------------------------------------------------------------------------

set -e

LOGROTATE_CONFIG_NAME="db_backups_logrotate" # Consistent name for easy removal
LOGROTATE_FILE_PATH="/etc/logrotate.d/$LOGROTATE_CONFIG_NAME"
DB_BACKUPS_LOG_DIR="/var/log/db_backups" # Main log directory for cron outputs

# Ensure script is run as root, though online_install.sh should handle this.
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This script must be run as root or with sudo to write to /etc/logrotate.d/." >&2
    exit 1
fi

echo "--- Logrotate Setup for db_backups ---"
echo "Setting up logrotate configuration..."
echo ""

# Ensure the log directory exists (online_install.sh also creates this)
echo "Ensuring log directory $DB_BACKUPS_LOG_DIR exists..."
if mkdir -p "$DB_BACKUPS_LOG_DIR"; then
    echo "Log directory $DB_BACKUPS_LOG_DIR ensured."
else
    echo "[WARNING] Could not create or verify log directory $DB_BACKUPS_LOG_DIR. Logrotation might not work as expected." >&2
    # Continue, as logrotate itself might create it based on 'create' directive, or fail gracefully.
fi
echo ""

# Logrotate configuration content
LOGROTATE_CONF_CONTENT=$(cat <<EOF
$DB_BACKUPS_LOG_DIR/*.log {
    weekly
    missingok
    rotate 10
    compress
    delaycompress
    notifempty
    create 0640 root adm
    sharedscripts
    postrotate
        # Example: Reload rsyslog if needed, though often not required for new .d files
        # if command -v systemctl &>/dev/null && systemctl is-active rsyslog &>/dev/null; then
        #    systemctl kill -s HUP rsyslog.service >/dev/null 2>&1 || true
        # fi
    endscript
}
EOF
)

echo "Writing logrotate configuration to $LOGROTATE_FILE_PATH..."
if echo -e "$LOGROTATE_CONF_CONTENT" > "$LOGROTATE_FILE_PATH"; then
    echo "Logrotate configuration written successfully."
    chmod 644 "$LOGROTATE_FILE_PATH"
    echo "Permissions set for $LOGROTATE_FILE_PATH."
else
    echo "[ERROR] Failed to write logrotate configuration to $LOGROTATE_FILE_PATH."
    exit 1
fi
echo ""

echo "Logrotate setup for db_backups complete."
echo "Logs for backup scripts (e.g., from cron) should be directed to files in $DB_BACKUPS_LOG_DIR ending with .log"
exit 0

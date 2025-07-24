#!/bin/bash
# =============================================================================
# Script: uninstall.sh
# Purpose: Uninstalls the db_backups tool from the system. It removes the
#          installed scripts, configuration directory, and logrotate file, and
#          advises on the manual removal of data, logs, cron jobs, and
#          dependencies.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.161500
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: sudo /usr/local/sbin/db_backups/uninstall.sh
#
# Notes:
# - Must be run as root or with sudo.
# - Asks for confirmation before proceeding.
# =============================================================================

# --- Configuration ---
SCRIPT_INSTALL_DIR="/usr/local/sbin/db_backups"
CONFIG_INSTALL_DIR="/etc/db_backups"
LOGROTATE_FILE_PATH="/etc/logrotate.d/db_backups_logrotate" # Must match the name used in setup_logrotate.sh

DATA_DIR="/var/backups/db_backups" # Corrected path
CACHE_DIR="/var/cache/db_backups"
LOG_DIR="/var/log/db_backups" # Main log directory for cron outputs

# --- Safety Checks ---
echo "--------------------------------------------------------------------"
echo " WARNING: This script will attempt to remove db_backups components."
echo "--------------------------------------------------------------------"
echo "It will try to remove:"
echo " - Scripts from: $SCRIPT_INSTALL_DIR"
echo " - Configuration from: $CONFIG_INSTALL_DIR"
echo " - Logrotate configuration: $LOGROTATE_FILE_PATH"
echo ""
echo "It will NOT automatically delete:"
echo " - Backup data in: $DATA_DIR"
echo " - Cache/temporary files in: $CACHE_DIR"
echo " - Log files in: $LOG_DIR"
echo " - Installed package dependencies (aws-cli, s3cmd, zip, bc, snapd)."
echo ""
echo "Please ensure you have backed up any critical data from these locations if needed."
echo "You will be responsible for manually removing cron jobs."
echo "--------------------------------------------------------------------"

# Check for root/sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This script must be run as root or with sudo." >&2
    exit 1
fi

# Confirmation prompt
read -r -p "Are you sure you want to uninstall db_backups? (Type 'yes' or 'y' to confirm): " confirmation
if ! [[ "$confirmation" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Uninstallation cancelled by user."
    exit 0
fi

echo "Proceeding with uninstallation..."
echo "----------------------------------------"

# --- Removal Steps ---

# 1. Remove scripts
if [ -d "$SCRIPT_INSTALL_DIR" ]; then
    echo "[INFO] Removing script directory: $SCRIPT_INSTALL_DIR..."
    rm -rf "$SCRIPT_INSTALL_DIR"
    if [ $? -eq 0 ]; then
        echo "[INFO] Script directory removed."
    else
        echo "[WARN] Failed to remove script directory $SCRIPT_INSTALL_DIR. Please check permissions or remove manually."
    fi
else
    echo "[INFO] Script directory $SCRIPT_INSTALL_DIR not found, skipping."
fi
echo "----------------------------------------"

# 2. Remove configuration
if [ -d "$CONFIG_INSTALL_DIR" ]; then
    echo "[INFO] Removing configuration directory: $CONFIG_INSTALL_DIR..."
    rm -rf "$CONFIG_INSTALL_DIR"
    if [ $? -eq 0 ]; then
        echo "[INFO] Configuration directory removed."
    else
        echo "[WARN] Failed to remove configuration directory $CONFIG_INSTALL_DIR. Please check permissions or remove manually."
    fi
else
    echo "[INFO] Configuration directory $CONFIG_INSTALL_DIR not found, skipping."
fi
echo "----------------------------------------"

# 3. Remove logrotate configuration
if [ -f "$LOGROTATE_FILE_PATH" ]; then
    echo "[INFO] Removing logrotate file: $LOGROTATE_FILE_PATH..."
    rm -f "$LOGROTATE_FILE_PATH"
    if [ $? -eq 0 ]; then
        echo "[INFO] Logrotate file removed."
    else
        echo "[WARN] Failed to remove logrotate file $LOGROTATE_FILE_PATH. Please check permissions or remove manually."
    fi
else
    echo "[INFO] Logrotate file $LOGROTATE_FILE_PATH not found, skipping."
fi
echo "----------------------------------------"

# --- Final Advice ---
echo "[INFO] Core db_backups components have been removed."
echo ""
echo "Important Manual Steps Remaining:"
echo "1. Cron Jobs: Please manually check and remove any cron jobs associated with db_backups scripts."
echo "   (e.g., check 'sudo crontab -l', and files in /etc/cron.d/, /etc/cron.hourly, etc.)"
echo "2. Backup Data: If you wish to remove your actual backup files, manually delete the directory:"
echo "   $DATA_DIR"
echo "3. Cache: If you wish to remove temporary/cache files, manually delete the directory:"
echo "   $CACHE_DIR"
echo "4. Logs: If you wish to remove log files, manually delete the directory:"
echo "   $LOG_DIR"
echo "5. Dependencies: The following packages were installed by db_backups if not already present:"
echo "   - aws-cli (via snap)"
echo "   - s3cmd"
echo "   - zip"
echo "   - bc"
echo "   - snapd (if aws-cli was installed via snap and snapd wasn't present)"
echo "   These have NOT been uninstalled as they might be used by other system utilities."
echo "   If you are sure you no longer need them, you can remove them manually using your system's package manager (apt, snap)."
echo "   (e.g., 'sudo apt remove zip bc s3cmd', 'sudo snap remove aws-cli', 'sudo apt remove snapd')"
echo ""
echo "Uninstallation process complete."
exit 0

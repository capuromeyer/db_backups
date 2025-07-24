#!/bin/bash
# =============================================================================
# Script: online_install.sh
# Purpose: Installs the db_backups tool and its dependencies onto the system.
#          This includes creating FHS-compliant directories, cloning the source,
#          copying scripts, setting up a sample configuration, installing
#          required packages, and setting up log rotation.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.160900
# Project Version: 1.0.0
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: curl -sSL https://raw.githubusercontent.com/capuromeyer/db_backups/jules/online_install.sh | sudo bash
#
# Notes:
# - Must be run as root or with sudo.
# - Assumes a Debian-based system for 'apt' package management.
# - Idempotent to some extent (e.g., won't overwrite existing config).
# - This script relies on the 'jules' branch of the db_backups repository.
#   For a production environment, consider cloning a stable release tag or the
#   'main' branch.
# =============================================================================

set -e

# --- Helper Functions (defined early to be available for initial checks) ---
info() {
    echo "[INFO] $1"
}

warn() {
    echo "[WARN] $1" >&2
}

error_exit() {
    echo "[ERROR] $1" >&2
    # Cleanup if TMP_CLONE_DIR was created and variable is set
    if [ -n "$TMP_CLONE_DIR" ] && [ -d "$TMP_CLONE_DIR" ]; then
        info "Cleaning up temporary directory: $TMP_CLONE_DIR..."
        rm -rf "$TMP_CLONE_DIR"
    fi
    exit 1
}

echo "--------------------------------------------------------------------"
echo "Welcome to the db_backups Installer!"
echo "--------------------------------------------------------------------"
echo "This script will perform the following actions to install db_backups:"
echo ""
echo "1. Check for root/sudo privileges (required)."
echo "2. Check for Git and install it via 'apt' if missing (for Debian-based systems)."
echo "3. Create necessary directories under FHS standard paths:"
echo "    - Scripts: /usr/local/sbin/db_backups/"
echo "    - Configuration: /etc/db_backups/"
echo "    - User Project Configurations: /etc/db_backups/conf.d/"
echo "    - Auto-generated Configurations: /etc/db_backups/autogen_conf.d/"
echo "    - Sample Project Configurations: /etc/db_backups/conf.d.sample/"
echo "    - Default Local Backups: /var/backups/db_backups/"
echo "    - Default Temporary Files: /var/cache/db_backups/"
echo "    - Logs: /var/log/db_backups/"
echo "4. Clone the db_backups repository from GitHub into a temporary location."
echo "5. Copy scripts from the repository to /usr/local/sbin/db_backups/ and set permissions."
echo "6. Copy a sample main configuration to /etc/db_backups/db_backups.conf (if no config exists there)."
echo "7. Copy sample project configurations to /etc/db_backups/conf.d.sample/."
echo "8. Run the internal dependency installer (/usr/local/sbin/db_backups/install_dependencies.sh),"
echo "    which will attempt to install: aws-cli (via snap), s3cmd, zip, bc, snapd, and"
echo "    relevant database client tools (e.g., postgresql-client, mariadb-client)."
echo "9. Set up log rotation for backup logs."
echo ""
echo "You will be prompted for your password if 'sudo' needs to elevate privileges for installations."
echo "--------------------------------------------------------------------"

# Check if running in an interactive terminal for confirmation
if [ ! -t 0 ]; then # Check if stdin (file descriptor 0) is not a terminal
    info "Running in non-interactive mode (e.g., via 'curl | bash')."
    info "The script will proceed automatically after displaying the actions to be performed."
    info "If you prefer to confirm each step or review more carefully, please download the script"
    info "and run it directly: "
    info "  1. curl -sSLO https://raw.githubusercontent.com/capuromeyer/db_backups/jules/online_install.sh"
    info "  2. chmod +x online_install.sh"
    info "  3. sudo ./online_install.sh"
    info "Proceeding with automatic installation in 3 seconds (Press Ctrl+C to abort)..."
    sleep 3
    # No actual confirmation read, assume 'yes' and proceed.
else
    # Stdin is a TTY, so prompt for confirmation
    read -r -p "Do you want to proceed with the installation? [Y/n]: " confirmation_install
    # Default to Yes if user just presses Enter
    if [[ "$confirmation_install" =~ ^([nN][oO]|[nN])$ ]]; then
        echo "Installation cancelled by user."
        exit 0
    elif [[ "$confirmation_install" =~ ^([yY][eE][sS]|[yY])$ ]] || [ -z "$confirmation_install" ]; then
        echo "Proceeding with installation..."
    else
        echo "Invalid input. Installation cancelled."
        exit 1
    fi
fi

echo "Starting db_backups installation..."
echo "----------------------------------------"

# --- Configuration ---
REPO_URL="https://github.com/capuromeyer/db_backups.git"
# IMPORTANT: For a production release, consider changing REPO_BRANCH to 'main' or a specific release tag.
REPO_BRANCH="jules" # Current development branch

SCRIPT_INSTALL_DIR="/usr/local/sbin/db_backups"
CONFIG_INSTALL_DIR="/etc/db_backups"
LOCAL_BACKUP_ROOT_INSTALL_DIR="/var/backups/db_backups"
TEMP_DIR_INSTALL_DIR="/var/cache/db_backups"
LOG_DIR_INSTALL_DIR="/var/log/db_backups" # For cron job logs

TMP_CLONE_DIR="/tmp/db_backups_install.$(date +%s)"

# --- Sanity Checks ---
info "Performing sanity checks..."

# 1. Check for root/sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    error_exit "You need to run this script with root privileges or using sudo. Please try again with 'sudo'."
fi
info "Root/sudo privileges: OK"

# 2. Check for Git
if ! command -v git &> /dev/null; then
    warn "Git is not installed. Attempting to install Git..."
    if apt update && apt install -y git; then
        info "Git installed successfully."
    else
        error_exit "Failed to install Git. Please install Git manually and re-run this script."
    fi
else
    info "Git is already installed."
fi
echo "----------------------------------------"

# --- Create Target Directories ---
info "Creating target directories..."
mkdir -p "$SCRIPT_INSTALL_DIR" || error_exit "Failed to create script directory: $SCRIPT_INSTALL_DIR"
mkdir -p "$CONFIG_INSTALL_DIR" || error_exit "Could not create the configuration directory: $CONFIG_INSTALL_DIR. Please check permissions."
mkdir -p "$CONFIG_INSTALL_DIR/conf.d" || error_exit "Could not create the user project configuration directory: $CONFIG_INSTALL_DIR/conf.d. Please check permissions."
mkdir -p "$CONFIG_INSTALL_DIR/autogen_conf.d" || error_exit "Could not create the auto-generated configuration directory: $CONFIG_INSTALL_DIR/autogen_conf.d. Please check permissions." # NEW
mkdir -p "$CONFIG_INSTALL_DIR/conf.d.sample" || error_exit "Could not create the sample project configuration directory: $CONFIG_INSTALL_DIR/conf.d.sample. Please check permissions." # For project samples
mkdir -p "$LOCAL_BACKUP_ROOT_INSTALL_DIR" || error_exit "Could not create the local backup root directory: $LOCAL_BACKUP_ROOT_INSTALL_DIR. Please check permissions."
mkdir -p "$TEMP_DIR_INSTALL_DIR" || error_exit "Could not create the temporary files directory: $TEMP_DIR_INSTALL_DIR. Please check permissions."
mkdir -p "$LOG_DIR_INSTALL_DIR" || error_exit "Could not create the log directory: $LOG_DIR_INSTALL_DIR. Please check permissions."
info "Target directories created/ensured."
echo "----------------------------------------"

# --- Clone Repository and Copy Files ---
info "Cloning repository from $REPO_URL (branch: $REPO_BRANCH) into $TMP_CLONE_DIR..."
if git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$TMP_CLONE_DIR"; then
    info "Repository cloned successfully."
else
    error_exit "The script could not download the necessary files from the repository at $REPO_URL. Please check if the URL is correct and your internet connection is stable."
fi

info "Copying scripts to $SCRIPT_INSTALL_DIR..."
# The repository structure is assumed to have a 'staging_root' directory
# that mirrors the target FHS structure.
STAGED_SCRIPTS_DIR="$TMP_CLONE_DIR/staging_root/usr/local/sbin/db_backups"
if [ ! -d "$STAGED_SCRIPTS_DIR" ]; then
    error_exit "Staged scripts directory '$STAGED_SCRIPTS_DIR' not found in cloned repository. Check REPO_URL and REPO_BRANCH."
fi

# Copy all contents from the staged script directory
if cp -R "$STAGED_SCRIPTS_DIR/." "$SCRIPT_INSTALL_DIR/"; then
    info "Scripts copied successfully."
else
    error_exit "The script was unable to copy the necessary files to the installation directory ($SCRIPT_INSTALL_DIR). This could be due to permissions issues. Please ensure the script has write access to this directory."
fi

info "Setting script permissions..."
# Set execute permissions for all .sh scripts in the main script directory and its 'lib' subdirectory
if chmod +x "$SCRIPT_INSTALL_DIR"/*.sh && \
   [ -d "$SCRIPT_INSTALL_DIR/lib" ] && \
   chmod +x "$SCRIPT_INSTALL_DIR"/lib/*.sh; then
    # Also check for 'dependencies' directory if it exists and set permissions there
    if [ -d "$SCRIPT_INSTALL_DIR/dependencies" ]; then
        chmod +x "$SCRIPT_INSTALL_DIR"/dependencies/*.sh || warn "Failed to set execute permissions for scripts in '$SCRIPT_INSTALL_DIR/dependencies'."
    fi
    info "Script permissions set successfully."
else
    error_exit "Failed to set script permissions in '$SCRIPT_INSTALL_DIR' or its subdirectories."
fi

info "Copying uninstall script to $SCRIPT_INSTALL_DIR/uninstall.sh..."
# uninstall.sh is typically at the root of the cloned repo
if cp "$TMP_CLONE_DIR/uninstall.sh" "$SCRIPT_INSTALL_DIR/uninstall.sh"; then
    chmod +x "$SCRIPT_INSTALL_DIR/uninstall.sh"
    info "Uninstall script copied and made executable."
else
    warn "Failed to copy uninstall.sh. Uninstallation might need to be done manually by fetching the script again."
fi
echo "----------------------------------------"

# --- Setup Configuration File ---
info "Setting up configuration files in $CONFIG_INSTALL_DIR..."
STAGED_SAMPLE_MAIN_CONFIG_PATH="$TMP_CLONE_DIR/staging_root/etc/db_backups/db_backups.conf.sample"
FINAL_SAMPLE_MAIN_CONFIG_PATH="$CONFIG_INSTALL_DIR/db_backups.conf.sample"
MAIN_MANIFEST_CONFIG_PATH="$CONFIG_INSTALL_DIR/db_backups.conf"

if [ ! -f "$STAGED_SAMPLE_MAIN_CONFIG_PATH" ]; then
    error_exit "Original sample main configuration file '$STAGED_SAMPLE_MAIN_CONFIG_PATH' not found in cloned repository."
fi

# Always copy/update the .sample file in /etc/db_backups/
info "Ensuring latest sample main configuration is available at $FINAL_SAMPLE_MAIN_CONFIG_PATH..."
if cp "$STAGED_SAMPLE_MAIN_CONFIG_PATH" "$FINAL_SAMPLE_MAIN_CONFIG_PATH"; then
    info "Latest sample main manifest file placed at $FINAL_SAMPLE_MAIN_CONFIG_PATH."
    chmod 644 "$FINAL_SAMPLE_MAIN_CONFIG_PATH" # Make sample readable
else
    error_exit "Failed to copy sample main manifest to $FINAL_SAMPLE_MAIN_CONFIG_PATH."
fi

# Handle the main configuration file db_backups.conf
if [ -f "$MAIN_MANIFEST_CONFIG_PATH" ]; then
    warn "Main manifest file '$MAIN_MANIFEST_CONFIG_PATH' already exists and was NOT overwritten."
    info "The latest sample main manifest is available at '$FINAL_SAMPLE_MAIN_CONFIG_PATH'."
    info "Please review it for new options or changes and update your existing configuration manually if needed."
else
    info "Creating main manifest file '$MAIN_MANIFEST_CONFIG_PATH' from the latest sample..."
    if cp "$FINAL_SAMPLE_MAIN_CONFIG_PATH" "$MAIN_MANIFEST_CONFIG_PATH"; then
        info "Main manifest file created. IMPORTANT: Please review '$MAIN_MANIFEST_CONFIG_PATH' and set up your project configurations."
    else
        error_exit "Failed to create main manifest file '$MAIN_MANIFEST_CONFIG_PATH' from sample."
    fi
fi

info "Setting permissions for main manifest file '$MAIN_MANIFEST_CONFIG_PATH' to 600..."
if chmod 600 "$MAIN_MANIFEST_CONFIG_PATH"; then
    info "Permissions set successfully for '$MAIN_MANIFEST_CONFIG_PATH'."
else
    warn "Failed to set permissions for '$MAIN_MANIFEST_CONFIG_PATH'. Please set them manually (e.g., sudo chmod 600 $MAIN_MANIFEST_CONFIG_PATH)."
fi

# Copy sample include files if the conf.d.sample directory exists in the clone
STAGED_CONF_D_SAMPLE_DIR="$TMP_CLONE_DIR/staging_root/etc/db_backups/conf.d.sample"
FINAL_USER_CONF_D_DIR="$CONFIG_INSTALL_DIR/conf.d" # User's actual project configs go here
FINAL_AUTOGEN_CONF_D_DIR="$CONFIG_INSTALL_DIR/autogen_conf.d" # Auto-generated configs go here
FINAL_SAMPLE_CONF_D_DIR="$CONFIG_INSTALL_DIR/conf.d.sample" # Samples go here, directory already created

if [ -d "$STAGED_CONF_D_SAMPLE_DIR" ]; then
    if [ -n "$(ls -A "$STAGED_CONF_D_SAMPLE_DIR" 2>/dev/null)" ]; then # Check if directory is not empty
        info "Copying/Updating sample project configuration files in $FINAL_SAMPLE_CONF_D_DIR/..."
        # This will overwrite existing files in the destination if they came from the sample dir
        if cp -R "$STAGED_CONF_D_SAMPLE_DIR/." "$FINAL_SAMPLE_CONF_D_DIR/"; then # Copy contents
            info "Sample project configuration files copied/updated in $FINAL_SAMPLE_CONF_D_DIR/."
            find "$FINAL_SAMPLE_CONF_D_DIR" -type f -exec chmod 644 {} \; # Make samples readable
        else
            warn "Failed to copy sample project configuration files from $STAGED_CONF_D_SAMPLE_DIR to $FINAL_SAMPLE_CONF_D_DIR."
        fi
    else
        info "Staged sample project configuration directory '$STAGED_CONF_D_SAMPLE_DIR' is empty. Nothing to copy to $FINAL_SAMPLE_CONF_D_DIR."
    fi
    # Ensure the user's project config directories exist (they should have been created earlier)
    if [ ! -d "$FINAL_USER_CONF_D_DIR" ]; then # Should not happen due to earlier mkdir
        warn "User project config directory '$FINAL_USER_CONF_D_DIR' not found. This is unexpected."
    fi
    if [ ! -d "$FINAL_AUTOGEN_CONF_D_DIR" ]; then # Should not happen due to earlier mkdir
        warn "Auto-generated config directory '$FINAL_AUTOGEN_CONF_D_DIR' not found. This is unexpected."
    fi
else
    info "No staged sample project configuration directory ('$STAGED_CONF_D_SAMPLE_DIR') found in repository. Skipping copy to $FINAL_SAMPLE_CONF_D_DIR."
fi
echo "----------------------------------------"

# --- Install Dependencies ---
info "Running dependency installer script ($SCRIPT_INSTALL_DIR/install_dependencies.sh)..."
if "$SCRIPT_INSTALL_DIR/install_dependencies.sh"; then
    info "Dependency installation script completed successfully."
else
    # The dependency script itself should output specific errors.
    error_exit "Dependency installation script failed. Please check the output above for details."
fi
echo "----------------------------------------"

# --- Setup Logrotate ---
info "Setting up logrotate configuration..."
if "$SCRIPT_INSTALL_DIR/dependencies/setup_logrotate.sh"; then
    info "Logrotate setup script completed successfully."
else
    # The logrotate script itself should output specific errors.
    warn "Logrotate setup script failed or reported issues. Please check output above. Log rotation may not function correctly."
    # This is not necessarily a fatal error for the whole installation, so using warn.
fi
echo "----------------------------------------"

# --- Cleanup ---
info "Cleaning up temporary installation files..."
if rm -rf "$TMP_CLONE_DIR"; then
    info "Temporary files cleaned up successfully ($TMP_CLONE_DIR)."
else
    warn "Failed to remove temporary directory: $TMP_CLONE_DIR. You may want to remove it manually."
fi
echo "----------------------------------------"

# --- Final Instructions ---
info "db_backups installation process complete!"
echo ""
echo "+++++==== IMPORTANT: Next Steps ====+++++"
echo "      1. - Review the main manifest file:"
echo "        sudo nano $MAIN_MANIFEST_CONFIG_PATH"
echo "        This file uses 'include' directives to point to project-specific configurations"
echo "        from '$FINAL_USER_CONF_D_DIR/' and '$FINAL_AUTOGEN_CONF_D_DIR/'."
echo ""
echo "      2. - Create your project-specific configuration(s):"
echo "        a. Copy the sample project configuration:"
echo "          sudo cp $FINAL_SAMPLE_CONF_D_DIR/project.conf.sample $FINAL_USER_CONF_D_DIR/my_project.conf"
echo "        b. Edit your new project configuration file with your specific database details, cloud storage settings (if any),"
echo "          paths, TTLs, and MOST IMPORTANTLY, the BACKUP_FREQUENCY_<PERIOD>=\"on\" flags:"
echo "          sudo nano $FINAL_USER_CONF_D_DIR/my_project.conf"
echo "        c. Ensure the 'include' line for '$FINAL_USER_CONF_D_DIR/my_project.conf' is active (uncommented)"
echo "          in the main manifest file ('$MAIN_MANIFEST_CONFIG_PATH')."
echo ""
echo "      3. - If using S3 or R2 cloud backups, configure your credentials:"
echo "        For AWS S3 (standard):"
echo "          sudo s3cmd --configure (for s3cmd)"
echo "          sudo aws configure (for AWS CLI, if not already done)"
echo "        For Cloudflare R2:"
echo "          a. Configure AWS CLI profile for R2 (e.g., 'r2-profile'):"
echo "             sudo aws configure --profile <your-r2-profile-name>"
echo "             (Use your R2 Access Key ID, Secret Access Key. For default region, enter 'auto' or leave blank.)"
echo "             Then, add the R2 endpoint URL to your AWS config file (e.g., /root/.aws/config):"
echo "               [profile <your-r2-profile-name>]"
echo "               region = auto"
echo "               output = json"
echo "               s3 ="
echo "                 endpoint_url = https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
echo "          b. Configure s3cmd for R2 (create a separate config file, e.g., ~/.s3cfg_r2):"
echo "             sudo s3cmd --configure -c /root/.s3cfg_r2"
echo "             (Provide R2 Access Key ID, Secret Access Key, and the R2 Endpoint URL.)"
echo "             Then, ensure R2_AWS_PROFILE_NAME and R2_S3CMD_CONFIG_PATH are set in your project.conf."
echo ""
echo "      4. - Test a backup frequency script (e.g., for hourly backups, if enabled in your project config):"
echo "        sudo $SCRIPT_INSTALL_DIR/hourly-backup.sh"
echo ""
echo "      5. - To uninstall the tool in the future, you can run:"
echo "        sudo $SCRIPT_INSTALL_DIR/uninstall.sh"
echo ""
echo "      6. - Set up cron jobs for automated backups as described in the project's README.md."
echo "        (Scripts are located in $SCRIPT_INSTALL_DIR)"
echo ""
echo "      Thank you for using db_backups!"

exit 0

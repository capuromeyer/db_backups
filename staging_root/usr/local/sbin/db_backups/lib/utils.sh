# Developed by: Alejandro Capuro (Project Lead & Logic Design)
# Implemented by: Jules (AI Assistant, under guidance)

# lib/utils.sh: General utility functions for the db_backups project.

# Function to check if the script is running as root.
# Outputs an error message and exits if not run as root.
check_root() {
    # Check if the effective user ID is 0 (root)
    if [ "$(id -u)" -ne 0 ]; then
        # Display a user-friendly error message with a specific prefix
        echo "[ERROR_PERMISSION] This operation requires root privileges." >&2
        echo "Please run this script using sudo: sudo $0" >&2
        # Exit with a status code indicating a permission error
        exit 1
    fi
    # Inform the user that the check passed
    echo "[INFO] Root privileges check passed."
    echo ""
}
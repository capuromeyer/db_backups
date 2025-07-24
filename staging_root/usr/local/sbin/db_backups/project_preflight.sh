#!/bin/bash
# =============================================================================
# Script: project_preflight.sh
# Purpose: Orchestrates all per-project configuration checks for a given file,
#          providing verbose output. This script is intended to be sourced,
#          and its main entry point is the `run_all_project_preflight_checks`
#          function.
# Copyright: (c) 2025 Alejandro Capuro Meyer. All rights reserved.
# License: GPL v3 - see LICENSE file for details
# Development: This script was developed with AI assistance (including Gemini,
#              ChatGPT, Claude, Jules, Firebase, and others) under human
#              guidance for architecture, logic design, and project direction.
# File Version: 20250723.161200
# Project Version: 1.0.0
# Project Repository: https://github.com/capuromeyer/db_backups
# Usage: This script is intended to be sourced by other scripts.
#
# Notes:
# - This script is not meant for direct execution.
# =============================================================================

# --- Global Variables for Preflight (scoped to this script) ---
# These variables will hold values derived during preflight checks.
# They are intended to be available to other sourced scripts (like actual_backup.sh)
# after a successful preflight run.
# Initializing them to ensure they are always defined.
PROJECT_NAME=""
SANITIZED_PROJECT_NAME=""
LOCAL_BACKUP_ROOT="" # This will be the user-defined root or the global default
TEMP_DIR=""          # This will be the derived project-specific temp directory (not customizable by user)
BACKUP_TYPE=""
DB_TYPE=""
DBS_TO_BACKUP=""
DB_USER=""
DB_PASSWORD="" # Sensitive, but needed for validation checks
S3_BUCKET_NAME=""
S3_PATH=""           # Variable from user's .conf file for the S3 path/prefix
S3_FULL_PATH=""      # Derived full S3 path (e.g., s3://mybucket/my_custom_backups/)
CLOUD_STORAGE_PROVIDER="" # e.g., "s3", "r2", "b2"

# R2 Specific Credentials/Configuration Names (NEW)
R2_AWS_PROFILE_NAME=""   # Name of the AWS CLI profile for R2 (e.g., 'r2')
R2_S3CMD_CONFIG_PATH=""  # Path to the s3cmd config file for R2 (e.g., '~/.s3cfg_r2')
# R2_ENDPOINT_URL is now expected to be configured within the R2_AWS_PROFILE_NAME in ~/.aws/config
# and within the R2_S3CMD_CONFIG_PATH file.

TIMESTAMP_STRING="" # Will be set by the calling script (project_list_processor.sh)
TTL_MINUTELY_BACKUP=""
TTL_HOURLY_BACKUP=""
TTL_DAILY_BACKUP=""
TTL_WEEKLY_BACKUP=""
TTL_MONTHLY_BACKUP=""
TTL_YEARLY_BACKUP=""

_PROJECT_ERROR_FLAG=0 # Internal flag for current project's preflight status

# --- Logging Helper (for project_preflight.sh) ---
# Function: _log_project_message
# Purpose: Standardized logging helper for messages from this script.
# Arguments: $1 - Log level (INFO, WARN, ERROR)
#            $2 - Message to log
_log_project_message() {
    local level="$1"
    local message="$2"
    # Direct all messages to standard output
    case "$level" in
        INFO)  echo "[PROJECT_PREFLIGHT] INFO $message" ;;
        WARN)  echo "[PROJECT_PREFLIGHT] WARN $message" ;;
        ERROR) echo "[PROJECT_PREFLIGHT] ERROR $message" ;;
        *)     echo "[PROJECT_PREFLIGHT] UNKNOWN $message" ;; # Fallback
    esac
}

# --- Internal Helper Functions for Preflight Steps ---

# Function: _source_and_capture_config
# Purpose: Sources the project configuration file and captures its variables.
# Arguments: $1 - Path to the configuration file.
# Returns: 0 on success, 1 on failure.
_source_and_capture_config() {
    local config_file="$1"
    _log_project_message INFO "Sourcing configuration file: '$config_file'..."
    # Clear previous project's variables to prevent leakage if not done by caller
    PROJECT_NAME=""
    LOCAL_BACKUP_ROOT=""
    TEMP_DIR="" # Clear TEMP_DIR here, it will be re-derived
    BACKUP_TYPE=""
    DB_TYPE=""
    DBS_TO_BACKUP=""
    DB_USER="" # Clear DB_USER
    DB_PASSWORD="" # Clear DB_PASSWORD
    S3_BUCKET_NAME=""
    S3_PATH="" # Clear S3_PATH
    S3_FULL_PATH="" # Clear S3_FULL_PATH
    CLOUD_STORAGE_PROVIDER="" # Clear CLOUD_STORAGE_PROVIDER
    R2_AWS_PROFILE_NAME="" # Clear R2_AWS_PROFILE_NAME
    R2_S3CMD_CONFIG_PATH="" # Clear R2_S3CMD_CONFIG_PATH
    TTL_MINUTELY_BACKUP=""
    TTL_HOURLY_BACKUP=""
    TTL_DAILY_BACKUP=""
    TTL_WEEKLY_BACKUP=""
    TTL_MONTHLY_BACKUP=""
    TTL_YEARLY_BACKUP=""

    # Source the config file
    # shellcheck source=/dev/null
    source "$config_file" || {
        _log_project_message ERROR "Failed to source config file '$config_file'. Check syntax or permissions."
        return 1
    }
    _log_project_message INFO "Configuration variables loaded."
    return 0
}

# Function: _validate_project_name
# Purpose: Validates and sanitizes the PROJECT_NAME variable.
# Sets SANITIZED_PROJECT_NAME global variable.
# Returns: 0 on success, 1 on failure.
_validate_project_name() {
    _log_project_message INFO "Validating PROJECT_NAME..."
    if [ -z "$PROJECT_NAME" ]; then
        _log_project_message ERROR "PROJECT_NAME is not set in the configuration."
        return 1
    fi
    # Sanitize PROJECT_NAME for use in paths/filenames (remove special chars)
    SANITIZED_PROJECT_NAME=$(echo "$PROJECT_NAME" | sed 's/[^a-zA-Z0-9_.-]/_/g')
    _log_project_message INFO "PROJECT_NAME: '$PROJECT_NAME' (Sanitized: '$SANITIZED_PROJECT_NAME')."
    return 0
}

# Function: _derive_and_validate_paths
# Purpose: Derives and validates LOCAL_BACKUP_ROOT and TEMP_DIR.
# Sets these global variables.
# Returns: 0 on success, 1 on failure.
_derive_and_validate_paths() {
    _log_project_message INFO "Deriving and validating LOCAL_BACKUP_ROOT and TEMP_DIR..."

    local default_local_backup_base="/var/backups/db_backups"
    local default_temp_base="/var/cache/db_backups"
    local local_backup_root_from_config="$LOCAL_BACKUP_ROOT" # Capture the value from config before modification

    # Handle LOCAL_BACKUP_ROOT (can be user-defined or default)
    if [ -z "$local_backup_root_from_config" ]; then
        # If not set by user, default to the global base path (no project name in path)
        LOCAL_BACKUP_ROOT="$default_local_backup_base"
        _log_project_message INFO "LOCAL_BACKUP_ROOT not set by user, defaulting to: '$LOCAL_BACKUP_ROOT'."
    elif [[ "$local_backup_root_from_config" == "$default_local_backup_base"* ]]; then
        # If user tried to set it to something like /var/backups/db_backups/projectX,
        # normalize it back to the base path, as project-specific subdirectories
        # are not desired here.
        LOCAL_BACKUP_ROOT="$default_local_backup_base"
        _log_project_message INFO "LOCAL_BACKUP_ROOT set by user to a default base subpath ('$local_backup_root_from_config'). Normalized to default: '$LOCAL_BACKUP_ROOT'."
    else
        # User explicitly set a custom path outside the default base. Use it.
        LOCAL_BACKUP_ROOT="$local_backup_root_from_config"
        _log_project_message INFO "LOCAL_BACKUP_ROOT explicitly set by user to custom path: '$LOCAL_BACKUP_ROOT'."
    fi

    # Handle TEMP_DIR (always derived, not user-customizable)
    if [ -z "$SANITIZED_PROJECT_NAME" ]; then
        _log_project_message ERROR "SANITIZED_PROJECT_NAME is not set, cannot derive TEMP_DIR."
        return 1
    fi
    TEMP_DIR="$default_temp_base/${SANITIZED_PROJECT_NAME}_temp"
    _log_project_message INFO "TEMP_DIR is derived to project-specific path: '$TEMP_DIR' (not user-customizable)."

    _log_project_message INFO "Final Paths: LOCAL_BACKUP_ROOT='$LOCAL_BACKUP_ROOT', TEMP_DIR='$TEMP_DIR'."
    return 0
}

# Function: _validate_backup_type
# Purpose: Validates the BACKUP_TYPE variable.
# Returns: 0 on success, 1 on failure.
_validate_backup_type() {
    _log_project_message INFO "Validating BACKUP_TYPE..."
    case "$BACKUP_TYPE" in
        local|cloud|both)
            _log_project_message INFO "BACKUP_TYPE: '$BACKUP_TYPE'."
            return 0
            ;;
        *)
            _log_project_message ERROR "Invalid BACKUP_TYPE: '$BACKUP_TYPE'. Allowed: local, cloud, both."
            return 1
            ;;
    esac
}

# Function: _validate_db_type
# Purpose: Validates the DB_TYPE variable.
# Returns: 0 on success, 1 on failure.
_validate_db_type() {
    _log_project_message INFO "Validating DB_TYPE..."
    case "$DB_TYPE" in
        mysql|mariadb|postgres|mongodb)
            _log_project_message INFO "DB_TYPE: '$DB_TYPE'."
            return 0
            ;;
        *)
            _log_project_message ERROR "Unsupported DB_TYPE: '$DB_TYPE'. Supported: mysql, mariadb, postgres, mongodb."
            return 1
            ;;
    esac
}

# Function: _validate_dbs_to_backup
# Purpose: Validates that DBS_TO_BACKUP is set.
# Returns: 0 on success, 1 on failure.
_validate_dbs_to_backup() {
    _log_project_message INFO "Validating DBS_TO_BACKUP..."
    if [ -z "$DBS_TO_BACKUP" ]; then
        _log_project_message ERROR "DBS_TO_BACKUP is not set. At least one database name is required."
        return 1
    fi
    _log_project_message INFO "DBS_TO_BACKUP: '$DBS_TO_BACKUP'."
    return 0
}

# Function: _validate_db_credentials
# Purpose: Validates that DB_USER is set (or defaulted for passwordless Postgres).
#          DB_PASSWORD is mandatory for MySQL/MariaDB/MongoDB, optional for PostgreSQL.
# Returns: 0 on success, 1 on failure.
_validate_db_credentials() {
    _log_project_message INFO "Validating DB credentials..."

    # DB_USER validation logic
    if [ -z "$DB_USER" ]; then
        if [[ "$DB_TYPE" == "postgres" && -z "$DB_PASSWORD" ]]; then
            _log_project_message INFO "DB_USER is not set for PostgreSQL with no password. Defaulting to 'postgres' OS user for peer authentication."
            DB_USER="postgres" # Default to 'postgres' OS user
        else
            _log_project_message ERROR "DB_USER is not set. It is mandatory for database type '$DB_TYPE' or when a password is provided for PostgreSQL."
            return 1
        fi
    else
        _log_project_message INFO "DB_USER: '$DB_USER'."
    fi

    # DB_PASSWORD validation logic
    if [[ "$DB_TYPE" == "mysql" || "$DB_TYPE" == "mariadb" || "$DB_TYPE" == "mongodb" ]]; then
        if [ -z "$DB_PASSWORD" ]; then
            _log_project_message ERROR "DB_PASSWORD is not set for database type '$DB_TYPE'. It is mandatory for this type."
            return 1
        fi
    elif [[ "$DB_TYPE" == "postgres" ]]; then
        if [ -z "$DB_PASSWORD" ]; then
            _log_project_message INFO "DB_PASSWORD is not set for PostgreSQL. This is allowed, assuming peer authentication or .pgpass will be used."
        else
            _log_project_message INFO "DB_PASSWORD is provided for PostgreSQL."
        fi
    fi

    _log_project_message INFO "DB credentials (USER/PASS) presence validated based on DB_TYPE."
    return 0
}

# Function: _validate_cloud_storage_settings
# Purpose: Validates cloud storage settings based on CLOUD_STORAGE_PROVIDER.
# Ensures the S3 bucket exists and creates the S3 prefix (folder) if it doesn't.
# Returns: 0 on success, 1 on failure.
_validate_cloud_storage_settings() {
    _log_project_message INFO "Validating cloud storage settings..."

    # If BACKUP_TYPE is not cloud or both, skip cloud validation
    if [[ "$BACKUP_TYPE" != "cloud" && "$BACKUP_TYPE" != "both" ]]; then
        _log_project_message INFO "Cloud backup not enabled (BACKUP_TYPE is '$BACKUP_TYPE'), skipping cloud storage settings validation."
        return 0
    fi

    # Validate CLOUD_STORAGE_PROVIDER
    if [ -z "$CLOUD_STORAGE_PROVIDER" ]; then
        _log_project_message WARN "CLOUD_STORAGE_PROVIDER is not set. Defaulting to 's3'."
        CLOUD_STORAGE_PROVIDER="s3"
    fi

    case "$CLOUD_STORAGE_PROVIDER" in
        "s3")
            _log_project_message INFO "Cloud storage provider: AWS S3."
            if [ -z "$S3_BUCKET_NAME" ]; then
                _log_project_message ERROR "S3_BUCKET_NAME is not set for S3 cloud backup."
                return 1
            fi

            local s3_validation_failed=0 # Flag to track if any S3 validation step fails

            # 1. Check for s3cmd executable
            if ! command -v s3cmd &>/dev/null; then
                _log_project_message ERROR "s3cmd command not found. Please install s3cmd to use S3 cloud backup."
                s3_validation_failed=1
            else
                _log_project_message INFO "s3cmd executable found."
            fi

            # 2. Check for AWS CLI executable
            if ! command -v aws &>/dev/null; then
                _log_project_message ERROR "aws CLI command not found. Please install AWS CLI to use S3 cloud backup."
                s3_validation_failed=1
            else
                _log_project_message INFO "AWS CLI executable found."
            fi

            # If executables are not found, no point in checking credentials or bucket
            if [ "$s3_validation_failed" -ne 0 ]; then
                _log_project_message ERROR "Missing required S3 command-line tools. Cloud storage settings validation FAILED."
                return 1 # Fail early if tools are missing
            fi

            # 3. Validate AWS CLI configuration (credentials and live command-line access)
            _log_project_message INFO "Verifying AWS CLI configuration (credentials and live command-line access)..."
            if ! aws sts get-caller-identity &>/dev/null; then
                _log_project_message ERROR "AWS CLI is not properly configured for S3 access. This could be due to invalid credentials, insufficient permissions, or network issues. Please run 'aws configure' and verify your AWS setup."
                s3_validation_failed=1
            else
                _log_project_message INFO "AWS CLI credentials and live command-line access validated."
            fi

            if [ "$s3_validation_failed" -ne 0 ]; then
                _log_project_message ERROR "S3 tool configuration failed. Cloud storage settings validation FAILED."
                return 1 # Fail if credentials are not validated
            fi

            # --- NEW TWO-STEP VALIDATION LOGIC ---

            # Step 4a: Validate S3 Bucket Existence and Accessibility
            _log_project_message INFO "STEP 4a: Validating S3 bucket '$S3_BUCKET_NAME' existence and accessibility..."
            # Attempt to get the bucket's region first to make head-bucket more robust
            local bucket_region=""
            # get-bucket-location returns JSON, parse it to get the region.
            # For 'us-east-1', LocationConstraint is null.
            bucket_region=$(aws s3api get-bucket-location --bucket "$S3_BUCKET_NAME" --query 'LocationConstraint' --output text 2>/dev/null)
            local get_location_status=$?

            if [ "$get_location_status" -ne 0 ]; then
                _log_project_message ERROR "Failed to get location for S3 bucket '$S3_BUCKET_NAME'. This likely means the bucket does not exist, or your credentials lack 's3:GetBucketLocation' permission."
                _log_project_message ERROR "Cloud storage settings validation FAILED."
                return 1 # Fail if we can't even get the bucket's location
            fi

            # If LocationConstraint is 'None' or empty, it's us-east-1
            if [ -z "$bucket_region" ] || [ "$bucket_region" == "None" ]; then
                bucket_region="us-east-1"
                _log_project_message INFO "Bucket '$S3_BUCKET_NAME' is in 'us-east-1' (default region)."
            else
                _log_project_message INFO "Bucket '$S3_BUCKET_NAME' is in region: '$bucket_region'."
            fi

            # Now, use head-bucket with the determined region to confirm existence and basic access
            if ! aws s3api head-bucket --bucket "$S3_BUCKET_NAME" --region "$bucket_region" &>/dev/null; then
                _log_project_message ERROR "S3 bucket '$S3_BUCKET_NAME' does not exist or you do not have permissions to access it in region '$bucket_region'."
                _log_project_message ERROR "Cloud storage settings validation FAILED."
                return 1 # Fail if bucket doesn't exist or is not accessible
            else
                _log_project_message INFO "S3 bucket '$S3_BUCKET_NAME' exists and is accessible."
            fi

            # Step 4b: Determine and Ensure S3 Folder (Prefix) Exists and is Writable
            _log_project_message INFO "STEP 4b: Determining and ensuring S3 folder (prefix) exists and is writable..."
            local s3_target_prefix_derived="" # Use a local variable for derivation

            # Use S3_PATH from the config file to construct the full S3 target prefix
            if [ -z "$S3_PATH" ]; then
                # If S3_PATH is not provided, use the default "db_backups/" prefix within the bucket
                s3_target_prefix_derived="s3://${S3_BUCKET_NAME}/db_backups/"
                _log_project_message INFO "S3_PATH not provided in config. Defaulting S3 target prefix to: '$s3_target_prefix_derived'."
            else
                # If S3_PATH is provided, use it directly.
                s3_target_prefix_derived="s3://${S3_BUCKET_NAME}/${S3_PATH}/"
                # Ensure it ends with a slash for consistent prefix behavior
                if [[ "${s3_target_prefix_derived: -1}" != "/" ]]; then
                    _log_project_message WARN "Derived S3 target prefix '$s3_target_prefix_derived' does not end with a slash. Appending it for consistency."
                    s3_target_prefix_derived="${s3_target_prefix_derived}/"
                fi
                _log_project_message INFO "S3_PATH provided in config. Using S3 target prefix: '$s3_target_prefix_derived'."
            fi

            # Set the global S3_FULL_PATH variable to the determined target prefix
            S3_FULL_PATH="$s3_target_prefix_derived"

            # Create a .keep file in the determined S3_FULL_PATH to ensure the prefix exists and is writable
            # Extract the key part from the full S3 path for put-object
            local s3_keep_file_key="$(echo "$S3_FULL_PATH" | sed "s|s3://${S3_BUCKET_NAME}/||").keep"
            _log_project_message INFO "Ensuring S3 target prefix '$S3_FULL_PATH' exists and is writable (via .keep file: '$s3_keep_file_key')..."

            # Create a dummy empty file to upload
            local dummy_file="/tmp/${SANITIZED_PROJECT_NAME}_s3_keep_dummy"
            touch "$dummy_file"

            # Attempt to upload the .keep file. This will create the prefix if it doesn't exist
            # and will fail if permissions are insufficient for the path.
            if ! aws s3api put-object --bucket "$S3_BUCKET_NAME" --key "$s3_keep_file_key" --body "$dummy_file" --region "$bucket_region" &>/dev/null; then
                _log_project_message ERROR "Failed to create or write to S3 target prefix '$S3_FULL_PATH' (via .keep file). Check write permissions for this path within the bucket."
                _log_project_message ERROR "Cloud storage settings validation FAILED."
                rm -f "$dummy_file" # Clean up dummy file
                return 1
            else
                _log_project_message INFO "S3 target prefix: '$S3_FULL_PATH' confirmed to exist and be writable (via .keep file)."
                rm -f "$dummy_file" # Clean up dummy file
            fi

            _log_project_message INFO "Cloud storage settings validated."
            ;;
        "r2")
            _log_project_message INFO "Cloud storage provider: Cloudflare R2."
            if [ -z "$S3_BUCKET_NAME" ]; then # R2 also uses S3_BUCKET_NAME
                _log_project_message ERROR "S3_BUCKET_NAME is not set for R2 cloud backup."
                return 1
            fi
            if [ -z "$R2_AWS_PROFILE_NAME" ]; then
                _log_project_message ERROR "R2_AWS_PROFILE_NAME is not set for R2 cloud backup. Please provide the name of your AWS CLI profile configured for R2."
                _log_project_message ERROR "To configure your AWS CLI for Cloudflare R2, run the following command and follow the prompts:"
                _log_project_message ERROR "  aws configure --profile <your-r2-profile-name>"
                _log_project_message ERROR "When prompted, use your R2 Access Key ID and Secret Access Key. For the default region, you can leave it blank or enter 'auto'."
                _log_project_message ERROR "Crucially, add your R2 endpoint to the profile in your AWS config file (e.g., ~/.aws/config or /root/.aws/config if running as root):"
                _log_project_message ERROR "  [profile <your-r2-profile-name>]"
                _log_project_message ERROR "  region = auto"
                _log_project_message ERROR "  output = json"
                _log_project_message ERROR "  s3 ="
                _log_project_message ERROR "    endpoint_url = https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
                _log_project_message ERROR "Cloud storage settings validation FAILED."
                return 1
            fi
            if [ -z "$R2_S3CMD_CONFIG_PATH" ]; then
                _log_project_message ERROR "R2_S3CMD_CONFIG_PATH is not set for R2 cloud backup. Please provide the path to your s3cmd config file for R2."
                _log_project_message ERROR "To configure s3cmd for Cloudflare R2, create a separate configuration file by running:"
                _log_project_message ERROR "  s3cmd --configure -c ~/.s3cfg_r2"
                _log_project_message ERROR "Follow the prompts, providing your R2 Access Key ID, Secret Access Key, and the R2 Endpoint URL (e.g., 'https://<ACCOUNT_ID>.r2.cloudflarestorage.com')."
                _log_project_message ERROR "Then, set R2_S3CMD_CONFIG_PATH in your project config to this file (e.g., R2_S3CMD_CONFIG_PATH=\"~/.s3cfg_r2\")."
                _log_project_message ERROR "Cloud storage settings validation FAILED."
                return 1
            fi

            local r2_validation_failed=0

            # Set AWS_CONFIG_FILE to ensure AWS CLI looks in /root/.aws/config when run as root
            # This is a temporary export for the duration of this function's scope.
            # It's crucial for sudo environments where HOME might not be correctly propagated.
            export AWS_CONFIG_FILE="/root/.aws/config"
            _log_project_message INFO "Temporarily setting AWS_CONFIG_FILE to '$AWS_CONFIG_FILE' for R2 validation."


            # 1. Check for s3cmd executable (using R2 config path)
            if ! command -v s3cmd &>/dev/null; then
                _log_project_message ERROR "s3cmd command not found. Please install s3cmd to use R2 cloud backup."
                r2_validation_failed=1
            else
                _log_project_message INFO "s3cmd executable found."
                # Verify s3cmd config file exists and is readable
                if [ ! -f "$R2_S3CMD_CONFIG_PATH" ]; then
                    _log_project_message ERROR "s3cmd config file for R2 not found at '$R2_S3CMD_CONFIG_PATH'. Please ensure it exists and is readable."
                    r2_validation_failed=1
                else
                    _log_project_message INFO "s3cmd config file for R2 found at '$R2_S3CMD_CONFIG_PATH'."
                fi
            fi

            # 2. Check for AWS CLI executable (using R2 profile)
            if ! command -v aws &>/dev/null; then
                _log_project_message ERROR "aws CLI command not found. Please install AWS CLI to use R2 cloud backup."
                r2_validation_failed=1
            else
                _log_project_message INFO "AWS CLI executable found."
                # Verify AWS CLI profile exists and is configured for R2
                if ! aws configure list-profiles | grep -q "$R2_AWS_PROFILE_NAME"; then
                    _log_project_message ERROR "AWS CLI profile '$R2_AWS_PROFILE_NAME' not found in your AWS CLI configuration. Please ensure it is correctly set up in '$AWS_CONFIG_FILE'."
                    r2_validation_failed=1
                else
                    _log_project_message INFO "AWS CLI profile '$R2_AWS_PROFILE_NAME' found in '$AWS_CONFIG_FILE'."
                _log_project_message INFO "AWS CLI profile '$R2_AWS_PROFILE_NAME' found in '$AWS_CONFIG_FILE'."
                fi
            fi

            if [ "$r2_validation_failed" -ne 0 ]; then
                _log_project_message ERROR "Missing required R2 command-line tools or configurations. Cloud storage settings validation FAILED."
                return 1
            fi

            # --- R2 TWO-STEP VALIDATION LOGIC ---

            # Step 3 (was 4a): Validate R2 Bucket Existence and Accessibility
            _log_project_message INFO "STEP 3: Validating R2 bucket '$S3_BUCKET_NAME' existence and accessibility using profile '$R2_AWS_PROFILE_NAME'..."
            # AWS_CONFIG_FILE is already exported.
            local aws_r2_head_bucket_command="aws s3api head-bucket --bucket \"$S3_BUCKET_NAME\" --profile \"$R2_AWS_PROFILE_NAME\""
            _log_project_message INFO "Executing command: $aws_r2_head_bucket_command"
            local aws_r2_head_bucket_output
            if ! aws_r2_head_bucket_output=$(eval "$aws_r2_head_bucket_command" 2>&1); then
                _log_project_message ERROR "R2 bucket '$S3_BUCKET_NAME' does not exist or you do not have permissions to access it with profile '$R2_AWS_PROFILE_NAME'."
                _log_project_message ERROR "AWS CLI output: $aws_r2_head_bucket_output" # Log the actual output
                # Check for specific AccessDenied error
                if [[ "$aws_r2_head_bucket_output" == *"AccessDenied"* ]]; then
                    _log_project_message ERROR "Received 'Access Denied' error. This indicates that your R2 API token/credentials for profile '$R2_AWS_PROFILE_NAME' do not have sufficient permissions for 's3:HeadBucket' on bucket '$S3_BUCKET_NAME'."
                    _log_project_message ERROR "Please ensure the R2 API token associated with this profile has appropriate permissions for this specific bucket."
                elif [[ "$aws_r2_head_bucket_output" == *"NotFound"* ]]; then
                    _log_project_message ERROR "Received 'NotFound' error. This indicates that the R2 bucket '$S3_BUCKET_NAME' does not exist."
                    _log_project_message ERROR "Please verify the S3_BUCKET_NAME in your project configuration."
                else
                    _log_project_message ERROR "An unexpected error occurred during R2 bucket validation. Please review the AWS CLI output for more details."
                fi
                _log_project_message ERROR "Cloud storage settings validation FAILED."
                return 1 # Fail if bucket doesn't exist or is not accessible
            else
                _log_project_message INFO "R2 bucket '$S3_BUCKET_NAME' exists and is accessible."
            fi

            # Step 4 (was 4b): Determine and Ensure R2 Folder (Prefix) Exists and is Writable
            _log_project_message INFO "STEP 4: Determining and ensuring R2 folder (prefix) exists and is writable..."
            local r2_target_prefix_derived="" # Use a local variable for derivation

            # Use S3_PATH from the config file to construct the full R2 target prefix
            if [ -z "$S3_PATH" ]; then
                # If S3_PATH is not provided, use the default "db_backups/" prefix within the bucket
                r2_target_prefix_derived="s3://${S3_BUCKET_NAME}/db_backups/"
                _log_project_message INFO "S3_PATH not provided in config. Defaulting R2 target prefix to: '$r2_target_prefix_derived'."
            else
                # If S3_PATH is provided, use it directly.
                r2_target_prefix_derived="s3://${S3_BUCKET_NAME}/${S3_PATH}/"
                # Ensure it ends with a slash for consistent prefix behavior
                if [[ "${r2_target_prefix_derived: -1}" != "/" ]]; then
                    _log_project_message WARN "Derived R2 target prefix '$r2_target_prefix_derived' does not end with a slash. Appending it for consistency."
                    r2_target_prefix_derived="${r2_target_prefix_derived}/"
                fi
                _log_project_message INFO "S3_PATH provided in config. Using R2 target prefix: '$r2_target_prefix_derived'."
            fi

            # Set the global S3_FULL_PATH variable to the determined target prefix (used by storage_cloud.sh)
            S3_FULL_PATH="$r2_target_prefix_derived"

            # Create a .keep file in the determined R2_FULL_PATH to ensure the prefix exists and is writable
            # Extract the key part from the full R2 path for put-object
            local r2_keep_file_key="$(echo "$S3_FULL_PATH" | sed "s|s3://${S3_BUCKET_NAME}/||").keep"
            _log_project_message INFO "Ensuring R2 target prefix '$S3_FULL_PATH' exists and is writable (via .keep file: '$r2_keep_file_key')..."

            # Create a dummy empty file to upload
            local dummy_file="/tmp/${SANITIZED_PROJECT_NAME}_r2_keep_dummy"
            touch "$dummy_file"

            # Attempt to upload the .keep file using the R2 profile.
            # AWS_CONFIG_FILE is already exported.
            local aws_r2_put_object_command="aws s3api put-object --bucket \"$S3_BUCKET_NAME\" --key \"$r2_keep_file_key\" --body \"$dummy_file\" --profile \"$R2_AWS_PROFILE_NAME\""
            _log_project_message INFO "Executing command: $aws_r2_put_object_command"
            local aws_r2_put_object_output
            if ! aws_r2_put_object_output=$(eval "$aws_r2_put_object_command" 2>&1); then
                _log_project_message ERROR "Failed to create or write to R2 target prefix '$S3_FULL_PATH' (via .keep file)."
                _log_project_message ERROR "AWS CLI output: $aws_r2_put_object_output" # Log the actual output
                _log_project_message ERROR "Check write permissions for this path within the bucket with profile '$R2_AWS_PROFILE_NAME'."
                _log_project_message ERROR "Cloud storage settings validation FAILED."
                rm -f "$dummy_file" # Clean up dummy file
                return 1
            else
                _log_project_message INFO "R2 target prefix: '$S3_FULL_PATH' confirmed to exist and be writable (via .keep file)."
                rm -f "$dummy_file" # Clean up dummy file
            fi

            _log_project_message INFO "Cloud storage settings validated."
            ;;
        "b2")
            _log_project_message ERROR "Cloud storage provider '$CLOUD_STORAGE_PROVIDER' is recognized but its specific validation and backup logic is not yet implemented."
            _log_project_message ERROR "Cloud backup for this project will NOT be performed as '$CLOUD_STORAGE_PROVIDER' is not fully supported."
            return 1 # This explicitly fails the preflight for this project if an unsupported cloud provider is chosen.
            ;;
        *)
            _log_project_message ERROR "Invalid CLOUD_STORAGE_PROVIDER: '$CLOUD_STORAGE_PROVIDER'. Supported: s3, r2. Future: b2."
            return 1 # Fail for truly unknown providers
            ;;
    esac

    return 0
}

# Function: _create_project_directories
# Purpose: Creates necessary directories for the project.
# Only creates LOCAL_BACKUP_ROOT if it's a user-defined custom path.
# Always creates TEMP_DIR (which is always project-specific).
# Returns: 0 on success, 1 on failure.
_create_project_directories() {
    _log_project_message INFO "Checking/Creating project directories..."

    local default_local_backup_base="/var/backups/db_backups"

    # Only create LOCAL_BACKUP_ROOT if it's a user-defined custom path
    # (i.e., not the default global path)
    if [[ "$LOCAL_BACKUP_ROOT" != "$default_local_backup_base" ]]; then
        _log_project_message INFO "Path: '$LOCAL_BACKUP_ROOT'"
        if [ ! -d "$LOCAL_BACKUP_ROOT" ]; then
            if ! sudo mkdir -p "$LOCAL_BACKUP_ROOT"; then
                _log_project_message ERROR "Failed to create directory: '$LOCAL_BACKUP_ROOT'."
                return 1
            fi
            _log_project_message INFO "Created directory: '$LOCAL_BACKUP_ROOT'."
        else
            _log_project_message INFO "'$LOCAL_BACKUP_ROOT' exists."
        fi
    else
        _log_project_message INFO "LOCAL_BACKUP_ROOT is default global path ('$LOCAL_BACKUP_ROOT'). Not creating project-specific subdirectory here."
    fi

    # Always create TEMP_DIR as it's designed to be project-specific and not customizable
    _log_project_message INFO "Path: '$TEMP_DIR'"
    if [ ! -d "$TEMP_DIR" ]; then
        if ! sudo mkdir -p "$TEMP_DIR"; then
            _log_project_message ERROR "Failed to create directory: '$TEMP_DIR'."
            return 1
        fi
        _log_project_message INFO "Created directory: '$TEMP_DIR'."
    else
        _log_project_message INFO "'$TEMP_DIR' exists."
    fi

    _log_project_message INFO "Project directories ensured."
    return 0
}

# Function: _validate_ttls
# Purpose: Validates Time-To-Live (TTL) settings.
# Requires ttl_parser.sh to be sourced.
# Returns: 0 on success, 1 on failure.
_validate_ttls() {
    _log_project_message INFO "Validating TTLs..."

    # Source ttl_parser.sh if not already sourced.
    # Assuming project_preflight.sh is in /usr/local/sbin/db_backups/
    # and ttl_parser.sh is in /usr/local/sbin/db_backups/lib/
    local TTL_PARSER_SCRIPT_PATH="$(dirname "${BASH_SOURCE[0]}")/lib/ttl_parser.sh" # Corrected path
    if [ ! -f "$TTL_PARSER_SCRIPT_PATH" ]; then
        _log_project_message ERROR "TTL parser script not found: '$TTL_PARSER_SCRIPT_PATH'. Cannot validate TTLs."
        return 1
    fi
    # shellcheck source=/dev/null
    source "$TTL_PARSER_SCRIPT_PATH" || {
        _log_project_message ERROR "Failed to source TTL parser script from '$TTL_PARSER_SCRIPT_PATH'. Check syntax or permissions."
        return 1
    }
    _log_project_message INFO "TTL parser loaded."

    local all_ttls_valid=0 # Flag to track overall TTL validation status

    # List of TTL variables to validate
    local ttls_to_check=("TTL_MINUTELY_BACKUP" "TTL_HOURLY_BACKUP" "TTL_DAILY_BACKUP" "TTL_WEEKLY_BACKUP" "TTL_MONTHLY_BACKUP" "TTL_YEARLY_BACKUP")

    for ttl_var in "${ttls_to_check[@]}"; do
        local ttl_value="${!ttl_var}" # Get the value of the variable
        local parsed_minutes

        if [ -z "$ttl_value" ]; then
            _log_project_message WARN "TTL '$ttl_var' is not set. Defaulting to 0 minutes (no retention)."
            # Set the variable to 0 if not defined, so it's consistent
            eval "$ttl_var=0"
            continue
        fi

        # Use the parse_human_ttl_to_minutes function from ttl_parser.sh (Corrected function name)
        parsed_minutes=$(parse_human_ttl_to_minutes "$ttl_value")
        local parse_status=$?

        if [ "$parse_status" -eq 0 ]; then
            _log_project_message INFO "TTL '$ttl_var': '$ttl_value' ($parsed_minutes mins)."
            # Update the global TTL variable with the parsed minutes
            eval "$ttl_var=$parsed_minutes"
        else
            _log_project_message ERROR "Invalid format for TTL '$ttl_var': '$ttl_value'. Expected format like '120m', '48h', '14d', '5w', '12M', '2y'."
            all_ttls_valid=1 # Mark overall validation as failed
        fi
    done

    if [ "$all_ttls_valid" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}


# -----------------------------------------------------------------------------
# FUNCTION: run_all_project_preflight_checks
# Purpose: Orchestrates all per-project configuration checks for a given file,
#          providing verbose output.
# To be called by the main script to validate a specific project config.
# Arguments: $1 - Path to the project configuration file to validate.
# Returns: 0 if all checks pass, 1 if any critical check fails.
# -----------------------------------------------------------------------------
run_all_project_preflight_checks() {
    local config_file_path="$1"
    _PROJECT_ERROR_FLAG=0 # Reset error flag for this specific project check
    local overall_project_status=0

    echo "----------------------------------------------------------------"
    _log_project_message INFO "Starting Preflight Checks Per Project"
    echo "Project Config: '$config_file_path' at $(date)"
    echo "----------------------------------------------------------------"
    echo ""

    # Step 1: Source and capture variables
    _log_project_message INFO "STEP 1/9: Sourcing and capturing configuration variables..."
    if ! _source_and_capture_config "$config_file_path"; then
        _PROJECT_ERROR_FLAG=1
        _log_project_message ERROR "Failed to source or capture variables from config file. Aborting."
    else
        _log_project_message INFO "Configuration variables loaded successfully."
    fi
    echo ""

    # Step 2: Validate PROJECT_NAME
    if [ "$_PROJECT_ERROR_FLAG" -eq 0 ]; then
        _log_project_message INFO "STEP 2/9: Validating PROJECT_NAME..."
        if ! _validate_project_name; then
            _PROJECT_ERROR_FLAG=1
            _log_project_message ERROR "PROJECT_NAME validation failed."
        else
            _log_project_message INFO "PROJECT_NAME validated."
        fi
    fi
    echo ""

    # Step 3: Derive and validate paths
    if [ "$_PROJECT_ERROR_FLAG" -eq 0 ]; then
        _log_project_message INFO "STEP 3/9: Deriving and validating backup/temp paths..."
        if ! _derive_and_validate_paths; then
            _PROJECT_ERROR_FLAG=1
            _log_project_message ERROR "Path derivation/validation failed."
        else
            _log_project_message INFO "Paths derived and validated."
        fi
    fi
    echo ""

    # Step 4: Validate BACKUP_TYPE
    if [ "$_PROJECT_ERROR_FLAG" -eq 0 ]; then
        _log_project_message INFO "STEP 4/9: Validating BACKUP_TYPE..."
        if ! _validate_backup_type; then
            _PROJECT_ERROR_FLAG=1
            _log_project_message ERROR "BACKUP_TYPE validation failed."
        else
            _log_project_message INFO "BACKUP_TYPE validated."
        fi
    fi
    echo ""

    # Step 5: Validate DB_TYPE
    if [ "$_PROJECT_ERROR_FLAG" -eq 0 ]; then
        _log_project_message INFO "STEP 5/9: Validating DB_TYPE..."
        if ! _validate_db_type; then
            _PROJECT_ERROR_FLAG=1
            _log_project_message ERROR "DB_TYPE validation failed."
        else
            _log_project_message INFO "DB_TYPE validated."
        fi
    fi
    echo ""

    # Step 6: Validating databases to backup and credentials
    if [ "$_PROJECT_ERROR_FLAG" -eq 0 ]; then
        _log_project_message INFO "STEP 6/9: Validating databases to backup and credentials..."
        if ! _validate_dbs_to_backup; then
            _PROJECT_ERROR_FLAG=1
            _log_project_message ERROR "DBS_TO_BACKUP validation failed."
        elif ! _validate_db_credentials; then
            _PROJECT_ERROR_FLAG=1
            _log_project_message ERROR "DB credentials validation failed."
        else
            _log_project_message INFO "Database settings validated."
        fi
    fi
    echo ""

    # Step 7: Validate Cloud Storage Settings (if applicable)
    if [ "$_PROJECT_ERROR_FLAG" -eq 0 ]; then
        _log_project_message INFO "STEP 7/9: Validating cloud storage settings (if cloud backup enabled)..."
        if ! _validate_cloud_storage_settings; then
            _PROJECT_ERROR_FLAG=1
            _log_project_message ERROR "Cloud storage settings validation failed."
        else
            _log_project_message INFO "Cloud storage settings validated."
        fi
    fi
    echo ""

    # Step 8: Create project-specific directories
    if [ "$_PROJECT_ERROR_FLAG" -eq 0 ]; then
        _log_project_message INFO "STEP 8/9: Creating project-specific directories..."
        if ! _create_project_directories; then
            _PROJECT_ERROR_FLAG=1
            _log_project_message ERROR "Failed to create project directories. Aborting."
        else
            _log_project_message INFO "Project directories ensured."
        fi
    fi
    echo ""

    # Step 9: Validate TTLs
    if [ "$_PROJECT_ERROR_FLAG" -eq 0 ]; then
        _log_project_message INFO "STEP 9/9: Validating Time-To-Live (TTL) settings..."
        if ! _validate_ttls; then
            _PROJECT_ERROR_FLAG=1
            _log_project_message ERROR "TTL validation failed."
        else
            _log_project_message INFO "TTL settings validated."
        fi
    fi
    echo ""


    echo "----------------------------------------------------------------"
    if [ "$_PROJECT_ERROR_FLAG" -eq 0 ]; then
        _log_project_message INFO "All preflight checks for config '$config_file_path' "
        echo "Completed SUCCESSFULLY."
        overall_project_status=0
    else
        _log_project_message ERROR "Preflight checks for config '$config_file_path' "
        echo "FAILED. Please review logs above."
        overall_project_status=1
    fi
    echo "----------------------------------------------------------------"
    echo ""

    return "$overall_project_status"
}

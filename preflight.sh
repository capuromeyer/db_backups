#!/bin/bash

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# - Version: 0.0.3
# - Date: Dec 2023
# - Author: Alejandro Capuro
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# Load config file
PATH_TO_CONFIG=$PWD/config.sh
TEMPORAL=$PWD/temporal
source "$PATH_TO_CONFIG" || { echo "Error: Unable to load configuration file $PATH_TO_CONFIG"; exit 1; }

S3_PATH=${S3_BUCKET::-1}/$S3_DIRECTORY
MINUTE_BACKUP_DIRECTORY=$LOCAL_BACKUP_DIRECTORY/minute
HOURLY_BACKUP_DIRECTORY=$LOCAL_BACKUP_DIRECTORY/hourly
DAILY_BACKUP_DIRECTORY=$LOCAL_BACKUP_DIRECTORY/daily
WEEKLY_BACKUP_DIRECTORY=$LOCAL_BACKUP_DIRECTORY/weekly
MONTHLY_BACKUP_DIRECTORY=$LOCAL_BACKUP_DIRECTORY/monthly

DRTS=(
        "$MINUTE_BACKUP_DIRECTORY"
        "$HOURLY_BACKUP_DIRECTORY"
        "$DAILY_BACKUP_DIRECTORY"
        "$WEEKLY_BACKUP_DIRECTORY"
        "$MONTHLY_BACKUP_DIRECTORY"
)

TEMP_EXISTS=2

#===================================================================
# TRAP ERRORS
#===================================================================
directory_errors=0
tempfiles=( )
cleanup() {
    rm -rf "${tempfiles[@]}"
}

trap cleanup 0

error() {
    local parent_lineno="$1"
    local message="$2"
    local code="${3:-1}"
    if [[ -n "$message" ]] ; then
        echo "Error on or near line ${parent_lineno}: ${message}; exiting with status ${code}"
    else
        echo "Error on or near line ${parent_lineno}; exiting with status ${code}"
    fi
    exit "${code}"
}
trap 'error ${LINENO}' ERR

#===================================================================
echo ""
echo "Preflight start"
#===================================================================
# Check Directories
#===================================================================
# Check that local directory exists
if [ ! -d "$LOCAL_BACKUP_DIRECTORY" ]; then
    echo ""
    echo " ------ ERROR ------"
    echo "[ERROR] See below for details"
    echo ""
    echo "Directory/Folder '$LOCAL_BACKUP_DIRECTORY' does not exist!"
    echo ""
    echo "To run this script properly, create a local directory where DB backups will be stored."
    echo "Use 'sudo mkdir -p $LOCAL_BACKUP_DIRECTORY' to create the directory."
    echo "After creating the directory, feel free to run this script again."
    echo ""
    echo "Script Stopped"
    echo ""
    directory_errors=1
else
    directory_errors=0
fi

case $directory_errors in
    1)
        exit 1
        ;;
    0)
        echo ""
        echo "Local $LOCAL_BACKUP_DIRECTORY directory exists... proceeding"
        # Create backup directories if they don't exist
        for dir in "${DRTS[@]}"; do
            if [ ! -d "$dir" ]; then
                echo ""
                echo "$dir directory does not exist!!"
                echo "Creating $dir directory for you..."
                mkdir -p "$dir" || { echo "Error: Unable to create directory $dir"; exit 1; }
            fi
        done
        ;;
esac #directory_errors

# Check that temp directory at PWD exists
while [ $TEMP_EXISTS -eq 2 ]; do
    if [ ! -d "$TEMPORAL" ]; then
        echo ""
        echo "$TEMPORAL does not exist!!"
        echo "Creating $TEMPORAL directory for you..."
        mkdir -p "$TEMPORAL" || { echo "Error: Unable to create directory $TEMPORAL"; exit 1; }
    else
        echo ""
        echo "Temp directory exists... proceeding"
        TEMP_EXISTS=3
    fi
done

# Check that S3 Bucket directory exists
aws s3 ls "$S3_PATH" >/dev/null 2>&1

if [[ $? -eq 0 ]]; then
    echo ""
    echo "Checking aws S3 for $S3_PATH directory... directory exists... proceeding"
else
    echo ""
    echo "Checking aws S3 for $S3_PATH directory... S3 Bucket Directory does not exist"
    echo "To run this script properly, create an S3 directory where DB backups will be stored."
    echo "Use S3 web interface at aws.amazon.com to create the directory."
    echo "After creating the directory, feel free to run this script again."
    echo ""
    echo "Script Stopped"
    echo ""
    exit 1
fi

# Check if .env file exists
if [ ! -f "$PWD/.env" ]; then
    echo ""
    echo " ------ ERROR ------"
    echo "[ERROR] See below for details"
    echo ""
    echo ".env file does not exist!"
    echo "Please create a .env file in the root directory of your project."
    echo "You can use the provided .env.sample file as a template."
    echo "After creating the .env file, feel free to run this script again."
    echo ""
    echo "Script Stopped"
    echo ""
    exit 1
else
    echo ""
    echo ".env file exists... proceeding"
fi

# Check TTL values
if [[ $TTL_MINUTELY_BACKUP -lt 60 || $TTL_HOURLY_BACKUP -lt 60 || $TTL_DAILY_BACKUP -lt 60 || $TTL_WEEKLY_BACKUP -lt 60 || $TTL_MONTHLY_BACKUP -lt 60 ]]; then
    echo ""
    echo " ------ ERROR ------"
    echo "[ERROR] See below for details"
    echo ""
    echo "One or more TTL values in config.sh is less than 1 minute!"
    echo "Please ensure that TTL values are set to at least 1 minute to avoid unintended deletion of backup files."
    echo ""
    echo "Script Stopped"
    echo ""
    exit 1
else
    echo ""
    echo "TTL values are valid... proceeding"
fi

#!/bin/bash
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# - Version: 0.0.3
# - Date: Dec 2023
# - Author: Alejandro Capuro
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

echo "///////////////////////////////////////////////////////////////////////////////"
echo "Daily Backup Script started at | $(date)"
cd "$(dirname "$0")";
WORKING_DIRECTORY=$PWD

#Load config file
PATH_TO_PREFLIGHT=$PWD/preflight.sh
TEMPORAL=$PWD/temporal
PATH_TO_CONFIG=$PWD/config.sh

source $PATH_TO_PREFLIGHT
# Load environment variables from .env file
source "$PWD/.env" || { echo "Error: Unable to load environment variables from .env"; exit 1; }
COUNTER_K=0

# For each Databse on the list, mysqldump and archive the file
echo "====================== Databases ======================"
for i in ${DBS[@]}
do
        echo " ------ Start of $i ------"
        cd $TEMPORAL
        NOW=$(date +%Y-%m-%d)
        DATABASE_FILE="${NOW}_${i}_backup.sql";
        DATABASE_FILE_ZIP="${DATABASE_FILE}.zip"
        sudo mysqldump -u $MARIA_USER -p$MARIA_PASSWORD $i > $DATABASE_FILE

        # Compress database file
        zip $DATABASE_FILE_ZIP $DATABASE_FILE
        # Cleanup
        cd $TEMPORAL
        sudo rm $DATABASE_FILE

        #Move to Backup Directory
        cd $TEMPORAL
        sudo mv "$DATABASE_FILE_ZIP" $DAILY_BACKUP_DIRECTORY
        COUNTER_K=$((COUNTER_K+1))
        echo "-----------------------------------------------"
done
echo "======================================================="
echo "In total $COUNTER_K databases has been backuped"

#Remove old Backups
TTR=""
TTR=$(echo "scale=1; $((TTL_DAILY_BACKUP)) / (24 * 60)" | bc)
echo "Removing Files ($TTR Days or older)"
cd $DAILY_BACKUP_DIRECTORY
sudo find *.zip -mmin +$((TTL_DAILY_BACKUP)) | xargs sudo rm -rfv
echo "Old files removed"
echo "Syncronizing Files with S3 Bucket ..."
s3cmd sync --skip-existing --delete-removed $LOCAL_BACKUP_DIRECTORY $S3_BUCKET$S3_DIRECTORY
echo "Script finnished running at | $(date)"
echo "///////////////////////////////////////////////////////////////////////////////"
echo ""
#!/bin/bash
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# - About: Script that extract MYSQL/MARIADB DB and Back them up locally.
# - Version: 0.0.1
# - Date: 05 Feb 2020
# - Author: Alejandro Capuro
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #



echo "///////////////////////////////////////////////////////////////////////////////"
echo "Daily Backup Script started at | $(date)"

#Load config file
PATH_TO_PREFLIGHT=$PWD/preflight.sh
TEMPORAL=$PWD/temporal
PATH_TO_CONFIG=$PWD/config.sh

source $PATH_TO_PREFLIGHT
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
echo "Removing old Files (45 Days or Older)"
cd $DAILY_BACKUP_DIRECTORY
sudo find *.zip -mtime +45 | xargs sudo rm -fRv
echo "Old files removed"
echo "Syncronizing Files with S3 Bucket ..."
s3cmd sync --skip-existing --delete-removed $S3_DIRECTORY $S3_BUCKET
echo "Script finnished running at | $(date)"
echo "///////////////////////////////////////////////////////////////////////////////"
echo ""

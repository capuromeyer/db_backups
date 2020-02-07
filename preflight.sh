#!/usr/bin/env bash
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# - About: Script for Backuping Database Files
# - Version: 0.0.1
# - Date: 5 Feb 2020
# - Author: Alejandro Capuro
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

#Load config file
PATH_TO_CONFIG=$PWD/config.sh
TEMPORAL=$PWD/temporal
source $PATH_TO_CONFIG

S3_PATH=${S3_BUCKET::-1}$S3_DIRECTORY
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
  rm -f "${tempfiles[@]}"
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
#Check Directories
#===================================================================
#Check that local directory exists
if [ ! -d $LOCAL_BACKUP_DIRECTORY ]
then
        echo ""
        echo " ------ ERROR ------"
        echo "[ERROR] $LOCAL_BACKUP_DIRECTORY directory does not exist!!"
        echo "Script Stoped"
        echo ""
        directory_errors=1
        script_errors=1
        #exit 1;
else
        directory_errors=0
fi
        case $directory_errors in
        1)
        exit 1
        ;;

        0)
        echo ""
        echo "Local $LOCAL_BACKUP_DIRECTORY directory exists ... proceeding"
        for dir in ${DRTS[@]}
        do
                if [ ! -d $dir ]; then
                echo ""
                echo "$dir directory does not exist!!"
                echo "creating $dir directory for you ..."
                sudo mkdir $dir
                fi
        done
        ;;

        esac #directory_errors


#check that temp directory at PWD exist
while [ $TEMP_EXISTS -eq 2 ]
        do
                if [ ! -d $TEMPORAL ]
                then
                        echo ""
                        echo "$TEMPORAL does not exists!!"
                        echo "creating $TEMPORAL directory for you..."
                        cd $PWD
                        sudo mkdir temporal
                else
                        echo ""
                        echo "Temp directory exists ... proceeding"
                        TEMP_EXISTS=3
                fi

        done

#check that S3 Bucket directory exists
aws s3 ls $S3_PATH >/dev/null 2>&1

if [[ $? -eq 0 ]]
then
        echo ""
        echo "Checking aws S3 for $S3_PATH directory ... directory exists ... proceeding"
else
        echo ""
        echo "S3 Bucket Directory do not exists"
        exit 1
fi

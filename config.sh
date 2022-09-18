#!/bin/bash
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# - About: Script for Backuping Database Files
# - Version: 0.0.1
# - Date: 5 Feb 2020
# - Author: Alejandro Capuro
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# List of Databases (MYSQL/MARIADB) to be backuped
DBS=(
        "database_01"
        "database_02"
        "database_03"
        "database_04"
)
# MariaDB Credentials
MARIA_USER='root'
MARIA_PASSWORD='password'

# Local Directory without trailing slash
LOCAL_BACKUP_DIRECTORY=/Local_Backup

# aws S3 Bucket [With trailing slash]
# example s3://your-bucket/
S3_BUCKET=s3://your-bucket/

# aws S3 Directory inside the Bucket [With trailing slash]
# example   Backup_Directory/
S3_DIRECTORY=S3_Backup_Directory/

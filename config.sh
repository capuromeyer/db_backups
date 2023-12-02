#!/bin/bash
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# - Version: 0.0.3
# - Date: Dec 2023
# - Author: Alejandro Capuro
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# List of Databases (MYSQL/MARIADB) to be backuped
DBS=(
        "database_01"
        "database_02"
        "database_03"
        "database_04"
)
#-------------------------------------
# Time to Live all

# Minutely
# ttl in minutes
# Removing old files (60 min or Older)
TTL_MINUTELY_BACKUP="60"

# Hourly
# ttl in minutes
# Removing old files (1 Days or Older)"
# 1 day = 60*24*1
TTL_HOURLY_BACKUP="2880"

# Daily
# ttl in minutes
# Removing old files (2 Days or Older)"
# 2 days = 60*24*2
TTL_DAILY_BACKUP=""

# Weekly
# ttl in minutes
# Removing old files (10 Weeks or Older)"
# 10 weeks = 60*24*7*10
TTL_WEEKLY_BACKUP="100800"

# Monthly
# ttl in minutes
# Removing old files (1.5 yrs or Older)"
# 1.5 years = 60*24*548
TTL_MONTHLY_BACKUP="789120"
#-------------------------------------

# Local Directory without trailing slash
LOCAL_BACKUP_DIRECTORY=/Local_Backup

# aws S3 Bucket [With trailing slash]
# example s3://your-bucket/
S3_BUCKET=s3://your-bucket/

# aws S3 Directory inside the Bucket [With trailing slash]
# example   Backup_Directory/
S3_DIRECTORY=S3_Backup_Directory/

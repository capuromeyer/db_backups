# db_backups
# Welcome!


## About

Simple script written in [BASH](https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html) to create periodic database backups in MYSQL / MARIADB.

Backups are created locally and can also be synchronizated with [AWS S3 Bucket](https://aws.amazon.com/s3/).

The script creates Minute, Hourly, Daily, Weekly and Monthly backups and also auto delete expired backups.

## Dependencies
The script needs the following technologies:
- BASH
-  AWS CLI
- S3cmd

## How to Install
### 1. Install aws cli

`# apt install awscli`


Run as root
`# aws configure`

Put you aws Credentials 
```
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```
More info about aws cli [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
### 2. Install S3cmd
 
`# apt install s3cmd`

Run as root
`s3cmd --configure`

```
Enter new values or accept defaults in brackets with Enter.
Refer to user manual for detailed description of all options.

Access key and Secret key are your identifiers for Amazon S3. Leave them empty for using the env variables.
Access Key: AKIAIOSFODNN7EXAMPLE
Secret Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default Region [US]:

Encryption password is used to protect your files from reading
by unauthorized persons while in transfer to S3
Encryption password: password
Path to GPG program [/usr/bin/gpg]:

When using secure HTTPS protocol all communication with Amazon S3
servers is protected from 3rd party eavesdropping. This method is
slower than plain HTTP, and can only be proxied with Python 2.7 or newer
Use HTTPS protocol [Yes]:

On some networks all internet access must go through an HTTP proxy.
Try setting it here if you can't connect to S3 directly
HTTP Proxy server name:

New settings:
Access Key: ACESSSSSSSSSSSSSKEEEEEEY
Secret Key: 8ujSecret/82xqHWZqT5UzT0OCzUVvKeyyy
Default Region: US
Encryption password: password
Path to GPG program: /usr/bin/gpg
Use HTTPS protocol: True
HTTP Proxy server name:
HTTP Proxy server port: 0

Test access with supplied credentials? [Y/n] y
Please wait, attempting to list all buckets...
Success. Your access key and secret key worked fine :-)

Now verifying that encryption works...
Success. Encryption and decryption worked fine :-)

Save settings? [y/N] y
Configuration saved to '/root/.s3cfg'
```
More info about S3cmd [here](https://s3tools.org/s3cmd)

### 3. Clone the Script
Clone the script on any directory you like.
### 4. Config File
Fill all the data on the configuration file `config.sh`
##### Databases
On DBS list all the name of all the databases to be backup. 
##### MariaDB/MySQL
User and password credential with privileges
##### Directories
Path to local and S3 directories, also S3 Bucket name. 

Example

```

# List of Databases (MYSQL/MARIADB) to be backuped
DBS=(
        "database_name_01"
        "other_database_02"
        "cool_project_database_03"        
)
# MariaDB Credentials
MARIA_USER='mysql_user'
MARIA_PASSWORD='password_to_mysql'

# Local Directory without trailing slash
LOCAL_BACKUP_DIRECTORY=/My_DB_Backups

# aws S3 Bucket with trailing slash
# example s3://your-bucket/
S3_BUCKET=s3://My-DBBackup-bucket/

# aws S3 Directory inside the Bucket
# example /Backup_Directory
S3_DIRECTORY=/My_DB_BackupsS3

```

### 5. Set execute permission
Go to the script directory where you save the script
`cd /path/to/script/directory`
set execute permission for all scripts
`sudo chmod +x *.sh`

### 6. Cronjobs
Set the cronjobs for your desire backups frequency.

##### Cronjob
Create cronjob as root. 

 `sudo crontab -e`

Recommended Example
```

# Every 5 min DB Backup
*/10 * * * * /path/to/directorymin-backup-s3.sh >> /var/log/db-backups-script/min.log
# Every Hour DB Backup
1 * * * * /path/to/directory/db_backups/hourly-backup-s3.sh >> /var/log/db-backups/hourly.log
# Every Day DB Backup at 04:00
0 4 * * * /path/to/directory/daily-backup-s3.sh >> /var/log/db-backups/daily.log
# Every Week on Monday at 00:01
1 0 * * MON /path/to/directory/weekly-backup-s3.sh >> /var/log/db-backups/weekly.log
# Every Month at 01:00
0 1 1 * * /path/to/directory/monthly-backup-s3.sh >> /var/log/db-backups/monthly.log

```
##### Every 10 Minute Backup
For every 10 minutes **local** backup you should create the following cronjob as root.
`# Every 5 min DB Backup
*/10 * * * * /path/to/directory/min-backup.sh >> /var/log/db-backups-script/min.log`

For **aws S3 synchronization** use this cronjob instead.
`# Every 5 min DB Backup`
`*/10 * * * * /path/to/directory/min-backup-s3.sh >> /var/log/db-backups-script/min.log`

##### Hourly Backup

For every hour **local** backup you should create the following cronjob as root.
`# Every Hour DB Backup`
`1 * * * * /path/to/directory/hourly-backup.sh >> /var/log/db-backups/hourly.log`

For **aws S3 synchronization** use this cronjob instead.
`# Every Hour DB Backup`
`1 * * * * /path/to/directory/hourly-backup-s3.sh >> /var/log/db-backups/hourly.log`

##### Daily Backup

For every day **local** backup you should create the following cronjob as root.
`# Every Day DB Backup at 04:00`
`0 4 * * * /path/to/directory/daily-backup.sh >> /var/log/db-backups/daily.log`

For **aws S3 synchronization** use this cronjob instead.
`# Every Day DB Backup at 04:00`
`0 4 * * * /path/to/directory/daily-backup-s3.sh >> /var/log/db-backups/daily.log`

##### Weekly Backup
For every week **local** backup you should create the following cronjob as root.
`# Every Week on Monday at 00:01`
`1 0 * * MON /path/to/directory/weekly-backup.sh >> /var/log/db-backups/weekly.log`

For **aws S3 synchronization** use this cronjob instead.
`# Every Week on Monday at 00:01`
`1 0 * * MON /path/to/directory/db_backups/weekly-backup-s3.sh >> /var/log/db-backups/weekly.log`

##### Monthly Backup
For every month **local** backup you should create the following cronjob as root.
`# Every Month at 01:00`
`0 1 1 * * /path/to/directory/monthly-backup.sh >> /var/log/db-backups/monthly.log`

For **aws S3 synchronization** use this cronjob instead.
`# Every Month at 01:00`
`0 1 1 * * /path/to/directory/monthly-backup-s3.sh >> /var/log/db-backups/monthly.log`



#
> README file written with [StackEdit](https://stackedit.io/).

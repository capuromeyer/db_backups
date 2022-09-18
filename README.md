# db_backups
# Welcome!


## About

Simple script written in [BASH](https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html) to create periodic database backups in MYSQL / MARIADB.

Backups are created locally and can also be synchronizated with [AWS S3 Bucket](https://aws.amazon.com/s3/).

The script creates Minute, Hourly, Daily, Weekly and Monthly backups and also auto delete expired backups.

## Dependencies
The script needs the following technologies:
- AWS Account and S3 Bucket
-  BASH
-  AWS CLI
- S3cmd

## How to Install
To use **db_backups** follow this steps.

### 1. Create your AWS Account and S3 Bucket
AWS (Amazon Web Sevices) 
To create you account go to https://aws.amazon.com/ and follow the step there to create your account. All new accounts get some free tier services.

After crearte your account, you need to create a new S3 Bucket for you backups, AWS have affordable prices for **S3 Buckets** (a Cloud Storage where your backups will live.).

You will also need to create a AWS user (other than your main one) that will be used to access your S3 Bucket from the **db_backups** script.

To generate your user credential (Access Key, ID Keys, etc) on your AWS account there are plenty of tutorial out there. If you need more help on how to setup yor S3 Bucket, AIM or other details related to AWS you can also check their  [official documentation](https://docs.aws.amazon.com/s3/index.html?nc2=h_ql_doc_s3).

### 2. Install aws cli
aws cli is the official tool of AWS to run commands (cli = command-line interface) that let us control some aspects of the cloud storage (aka S3 Bucket).

2.1 Install the tool
To install this tool on your server (the one where your Data Bases to be backup live) run this command as root.
 
`# apt install awscli`

2.2 Settings
To configure your settings run as root

`# aws configure`

The tool will ask you for you createndial

Put your aws Credentials (see step 1)
```
AWS Access Key ID [None]: EXAMPLEAKIAIOSFODNN7
AWS Secret Access Key [None]: EXAMPLEKEYwJalrXUtnFEMI/K7MDENG/bPxRfiCY
```

For more info about aws cli go [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
### 3. Install S3cmd
S3cmd is another tool, that let us control some aspect of the S3 Bucket, is need for the **db_backups** scripts to run properly.

3.1 Install the tool 
`# apt install s3cmd`

3.2 Settings
To configure your settings run as root
`s3cmd --configure`

Will prompt something similar to this:
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
You can put your AWS Access Key ID and AWS Secret Access Key when asked, all other default values are fine to leave untouch if you like.

This will generate a config file that you can acces later on this path `/root/.s3cfg`

For more info about S3cmd go [here](https://s3tools.org/s3cmd)

### 4. Clone the Script
Now that we have all dependencies installed we are ready to installing the **db_backups** script.

Clone the script on any directory you like inside you server (the server where you Databases live).

4.1 Script Directory
We will used this command 
 `$ sudo mkdir -p /tasks/db_backups` 
 to create the directory, but you are free to create any directory name in any path you like.

4.2 Script Clone
And we will used this command to clone the script

 `$ sudo git clone https://github.com/capuromeyer/db_backups.git /tasks/db_backups`

to clone the script to the directory we just created.

To clone the script go to up right hand is a button "Code", if you still need more help on how to clone read this [official documentation]( https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository).

4.3 Local Backups Directory
The **db_backups** scripts needs a local directory to run properly. You can create any directory you want in any path you like. In our case we will use:

 `$sudo mkdir /DB_Backups` 

That will create  our local directory.


### 5. Config File
We now need to put some configurations values, so the script can run properly.

Go to directory `$ cd /tasks/db_backups`

Open the configuration files `config.sh`  and fill all the data.

In our case we will use
`$ sudo nano config.sh` 
But you are free to use any text editor you like better.

##### Databases (DBS)
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
In our case we will use:
Our S3 Bucket name: *global-backups*
Our directory inside that bucket is: *DB_Backups*
And we will backup two databases: *WordpressDB_P102* and  *MagentoDB_P203* 

So our config file looks like this:
```

# List of Databases (MYSQL/MARIADB) to be backuped
DBS=(
        "WordpressDB_P102"
        "MagentoDB_P203"        
)

# MariaDB Credentials
MARIA_USER='backup_user'
MARIA_PASSWORD='password123456'

# Local Directory without trailing slash
LOCAL_BACKUP_DIRECTORY=/DB_Backups

# aws S3 Bucket with trailing slash
# example s3://your-bucket/
S3_BUCKET=s3://global-backups/

# aws S3 Directory inside the Bucket
# example /Backup_Directory
S3_DIRECTORY=/DB_Backups

```


### 6. Set execute permission
Now we need to give execution privileges to the files of the **db_backups** script.

Go to the script directory where you save the script
`cd /path/to/script/directory`
set execute permission for all scripts
`sudo chmod +x *.sh`

In our case `cd /tasks/db_backups` and `sudo chmod +x *.sh` 

### 7. Test
Test the script by running it.
`cd /tasks/db_backups`
`sudo ./min-backup-s3.sh`

The script will strart and you should see something like this.

```

///////////////////////////////////////////////////////////////////////////////
Minute Backup Script started at | Sun Sep 18 16:31:51 EST 2022

Preflight start

Local /DB_Backups directory exists ... proceeding

Temp directory exists ... proceeding

Checking aws S3 for s3://global-backups/DB_Backups/ directory ... directory exists ... proceeding
====================== Databases ======================
 ------ Start of WordpressDB_P102 ------
  adding: 2022-09-18-31_WordpressDB_P102_backup.sql (deflated 92%)
-----------------------------------------------
 ------ Start of MagentoDB_P203 ------
  adding: 2022-09-18-31_MagentoDB_P203_backup.sql (deflated 92%)
-----------------------------------------------
=======================================================
In total 2 databases has been backuped
Removing old Files (60 min or Older)
Old files removed
Syncronizing Files with S3 Bucket ...

...
...
...


Done. Uploaded 23022166 bytes in 1.0 seconds, 21.96 MB/s.
Script finnished running at | Sun Sep 18 16:32:10 EST 2022
///////////////////////////////////////////////////////////

```
You should see the files on you S3 buckets by now.
If all is correct you can proceed to the final step of creating your cronjobs. 



### 8. Cronjobs
Finally you can set the cronjobs for your desire backups frequency.

##### Cronjob
Create cronjob as root. 

 `sudo crontab -e`

Recommended Example **[with directories of our example]**
```

#============================== DataBases Backups Cron Jobs ===========================#
# MariaDB Database Backup | Every 15 min
*/15 * * * * /tasks/db_backups/min-backup-s3.sh >> /var/log/db-backups/01.min.log
# MariaDB Database Backup | Every Hour
1 * * * * /tasks/db_backups/hourly-backup-s3.sh >> /var/log/db-backups/02.hourly.log
# MariaDB Database Backup | Every Day at 04:03
3 4 * * * /tasks/db_backups/daily-backup-s3.sh >> /var/log/db-backups/03.daily.log
# MariaDB Database Backup | Every Week Monday at 00:02
2 0 * * MON /tasks/db_backups/weekly-backup-s3.sh >> /var/log/db-backups/04.weekly.log
# MariaDB Database Backup | Every Month at 01:07
7 1 1 * * /tasks/db_backups/monthly-backup-s3.sh >> /var/log/db-backups/05.monthly.log

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

Note: The script will automatically delete old backups. 

#
> README file written with [StackEdit](https://stackedit.io/).


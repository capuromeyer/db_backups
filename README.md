
# db_backups
# Welcome!

## About

This repository houses a simple yet powerful BASH script designed to automate the creation of periodic database backups for MYSQL/MARIADB. These backups can be generated locally and seamlessly synchronized with an [AWS S3 Bucket](https://aws.amazon.com/s3/).

The script supports various backup frequencies, including Minute, Hourly, Daily, Weekly, and Monthly intervals, and incorporates an automatic cleanup feature to remove expired backups.

## Dependencies

The script relies on the following technologies:

- AWS Account and S3 Bucket
- BASH
- AWS CLI
- S3cmd
- git
- zip
- bc

AWS Account is essential as the database backups are stored on AWS cloud services. BASH is required to execute the script, AWS CLI is used to interact with S3 through commands, S3cmd provides additional functionalities not covered by AWS CLI, git is used for cloning the script onto your server, zip is used for compressing SQL files, and bc is employed for minor mathematical calculations.

## Installation

To use **db_backups**, follow these steps:

### 1. Create your AWS Account and S3 Bucket

1.1. **AWS (Amazon Web Services):**
   - Visit [AWS](https://aws.amazon.com/) to create your account. New accounts typically include free tier services.
   - After creating your account, establish a new S3 Bucket for your backups. AWS offers cost-effective pricing for **S3 Buckets** (cloud storage for your backups).
   - Create a separate AWS user (apart from your main account) for accessing the S3 Bucket from the **db_backups** script.
   - Generate user credentials (Access Key, ID Keys, etc.) through your AWS account. Numerous tutorials are available for assistance. Refer to AWS's [official documentation](https://docs.aws.amazon.com/s3/index.html?nc2=h_ql_doc_s3) for details.

### 2. Install AWS CLI

2.1. **Install the tool:**
Run as root user.
   ```bash
   # apt install awscli
   ```

2.2. **Configuration:**
   ```bash
   # aws configure
   ```
   Provide your AWS credentials (Access Key and ID Keys) when prompted. For other parameters, it's safe to use the defaults by pressing Enter.

   For more information about AWS CLI, check [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).

### 3. Install S3cmd

3.1. **Install the tool:**
Run as root user.
   ```bash
   # apt install s3cmd
   ```

3.2. **Configuration:**
   ```bash
   s3cmd --configure
   ```
   Provide your AWS Access Key ID and AWS Secret Access Key when prompted. Other default values for settings are typically sufficient; just press Enter.

   For more information about S3cmd, check [here](https://s3tools.org/s3cmd).

### 4. Install Remaining Dependencies

4.1. **Install Zip:**
   ```bash
   $ sudo apt install zip
   ```

4.2. **Install Git:**
   ```bash
   $ sudo apt install git
   ```

4.3. **Install BC:**
   ```bash
   $ sudo apt install bc
   ```

### 5. Clone the Script

5.1. **Script Directory:**
   Create your local directory where the script will be saved.
   ```bash
   $ sudo mkdir -p /tasks/db_backups
   ```

5.2. **Script Clone:**
   Clone the script from the cloud to your local server in the directory created.
   ```bash
   $ sudo git clone https://github.com/capuromeyer/db_backups.git /tasks/db_backups
   ```

5.3. **Local Backups Directory:**
   Create another directory to store the actual database files.
   ```bash
   $ sudo mkdir /DB_Backups
   ```

### 6. Config File and Credentials File

Navigate to the script directory and open the `config.sh` file to fill in the required data.

Example:
   ```bash
   cd /tasks/db_backups
   sudo nano config.sh
   ```
   Edit the config file with your requirements.

Now create your credential file using the sample file; copy it with the name `.env`.

For example:
   ```bash
   sudo cp .env.sample .env
   ```

Edit the new `.env` file with a text editor:
   ```bash
   sudo nano .env
   ```

The file will look like this; enter your username and password:
   ```bash
   # === Backup Script Configuration ===
   # This file contains configuration values for the Backup Script.

   # MySQL/MariaDB Database Configuration
   MARIA_USER="your_user_mariadb_username"
   MARIA_PASSWORD="your_password_1234"
   ```
Delete sample file.
   ```bash
   cd /tasks/db_backups
   sudo rm -rfv .env.sample
   ```
### 7. Set Execute Permission

Give execution privileges to the script files.
   ```bash
   $ cd /tasks/db_backups
   $ sudo chmod +x *.sh
   ```

### 8. Test

Manually run the script to test its functionality.
   ```bash
   $ cd /tasks/db_backups
   $ sudo ./minutely-backup-s3.sh
   ```

### 9. Cronjobs

If you want to automate the process, set up cronjobs for desired backup frequencies. Examples:
   ```bash
   # Every 30 min DB Backup
   */30 * * * * /tasks/db_backups/minutely-backup-s3.sh >> /var/log/db-backups/01.minutely.log

   # Every Hour DB Backup
   1 * * * * /tasks/db_backups/hourly-backup-s3.sh >> /var/log/db-backups/02.hourly.log

   # Every Day DB Backup at 04:03
   3 4 * * * /tasks/db_backups/daily-backup-s3.sh >> /var/log/db-backups/03.daily.log

   # Every Week on Monday at 00:02
   2 0 * * MON /tasks/db_backups/weekly-backup-s3.sh >> /var/log/db-backups/04.weekly.log

   # Every Month at 01:07
   7 1 1 * * /tasks/db_backups/monthly-backup-s3.sh >> /var/log/db-backups/05.monthly.log
   ```

Note: The script automatically deletes old backups based on their type (weekly, monthly, hourly, etc.). To modify this parameter, edit it in the config.sh file.

> README file written with [StackEdit](https://stackedit.io/).

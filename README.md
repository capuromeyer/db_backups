# db_backups

## 1. Version

Project Version: **1.0.0**

## 2. About

**db_backups** is a lightweight, modular collection of Bash scripts designed to automate periodic database dumps for MySQL, MariaDB, and PostgreSQL.

Backups are organized by frequency (minutely, hourly, daily, weekly, monthly) and can be pushed to AWS S3 or Cloudflare R2. Old archives are cleaned up automatically based on configurable TTL (time-to-live).

## Features

-   **Flexible Frequency:** Minutely, hourly, daily, weekly, and monthly snapshots.   
-   **Multi-DB Support:** MySQL, MariaDB, PostgreSQL.
-   **Compression:** Dumps are zipped to save space.
-   **Cloud Sync:** Optional upload to AWS S3 or Cloudflare R2 (via aws-cli or s3cmd).
-   **Local Storage:** Can be configured to save backups locally.
-   **TTL-Based Cleanup:** Automatically prune old backups according to TTL settings.
-   **Cron-Friendly:** Frequency scripts for easy cron integration.
    
---
## 3. Quick Start

1.  Install the tool with the online installer.
2.  Set the bucket configurations (if you want cloud backups).
3.  Run a backup manually to test it.
4.  Set up the cronjob for the given frequency.
5.  Enjoy set-and-forget automation.
    
**Install via Online Installer** (as root):

`curl -sSL https://raw.githubusercontent.com/capuromeyer/db_backups/main/online_install.sh | sudo bash`

**Configure Credentials (S3)**:

 -   For **aws-cli**: aws configure (enter IAM user key, secret, default region).
`sudo aws configure`
 -   For **s3cmd**: s3cmd --configure (enter same credentials).
`sudo s3cmd --configure`

 -   For **R2**, both `aws configure` and `s3cmd --configure` are needed, **but you need to create a special profile**. (See more in the Cloudflare R2 installation section.)
    

 -  **Deploy Project Config**:
    - Duplicate project configuration files
    `sudo cp /etc/db_backups/conf.d.sample/project.conf.sample  /etc/db_backups/conf.d/project.conf`
    Edit it
	`sudo nano /etc/db_backups/conf.d/project.conf`

	- Duplicate global master manifest 
	`sudo cp /etc/db_backups/db_backups.conf.sample /etc/db_backups/db_backups.conf`
    Edit it to include (enable) the project in the manifest list
    `sudo nano /etc/db_backups/db_backups.conf`

- **Run a Test Backup**:
`sudo /usr/local/sbin/db_backups/dbb-tester.sh`
> The tester script uses hourly frequency. 
- **Create your cronjobs**
`sudo crontab -e`
` 1 * * * * /usr/local/sbin/db_backups/hourly.sh`

	--- Quick Start end. ---

---
## 4. Installation

### 4.1 Online Installer (Recommended)

This will install all dependencies and the necessary directory structure on your server:
`curl -sSL https://raw.githubusercontent.com/capuromeyer/db_backups/main/online_install.sh \
  | sudo bash`

#### 4.1.1 Manual Installation (Ubuntu example)
If you prefer to install it yourself, you need to install the dependencies and create the directory structure.
    
**Install General Dependencies**
To install general dependencies: Git (to pull the repository), Zip (to compress the database backup files), Snap (to install AWS CLI required for working with cloud buckets). 
```
sudo apt update
sudo apt install git zip snapd 
```
**Install Specific Dependencies**

AWS CLI
To install AWS CLI, you need to run the following. Note that this is a snap installer, so you need snap on your system previously to run this.
> AWS CLI is used to perform operations on the cloud bucket.

`sudo snap install aws-cli --classic`

S3CMD
To install s3cmd, you need to run: 
`sudo apt install s3cmd`
> S3cmd is used to take advantage of the sync functions, which allow you to save backups progressively (only missing non-uploaded parts)

### 4.2  Clone Repository:
    
```
sudo git clone https://github.com/capuromeyer/db_backups.git /opt/db_backups
```

### 4.3  Deploy Scripts:

```
sudo mkdir -p /usr/local/sbin/db_backups
sudo cp -r /opt/db_backups/staging_root/usr/local/sbin/db_backups/* \
  /usr/local/sbin/db_backups/
```

### 4.4  Deploy Configs:
    
```
sudo mkdir -p /etc/db_backups/conf.d /etc/db_backups/conf.d.sample /etc/db_backups/autogen_conf.d
sudo cp /opt/db_backups/staging_root/etc/db_backups/db_backups.conf /etc/db_backups/
sudo cp /opt/db_backups/staging_root/etc/db_backups/conf.d.sample/* \
  /etc/db_backups/conf.d.sample/
```

### 4.5  Make Scripts Executable:
    
```
sudo chmod +x /usr/local/sbin/db_backups/*.sh \
  /usr/local/sbin/db_backups/lib/*.sh
```


---

## 5. Configuration

For `db_backups` to run, we need to set up 3 configuration file sets:

1.  **Master Manifest Config:** `/etc/db_backups/db_backups.conf` – enables or disables database projects.
2.  **Per-Project Configs:** `/etc/db_backups/conf.d/your_project.conf` – sets the configuration needed for one project.
3.  **Credentials (third-party):** These are managed externally using either `aws configure` for AWS CLI or `s3cmd --configure` for S3CMD, which establish the necessary cloud credentials for S3/R2.

Apart from what is needed by AWS CLI and S3CMD, the configuration for `db_backups` set in `/etc/db_backups` is split across **two distinct files**, both of which are **required** for the system to work: **Master Manifest Config** and **Project Config File**.
    
#### 5.1  **Project Config File**
-   **Path:** `/etc/db_backups/conf.d/<project>.conf`
-   **Definition:** A **project** is a simple way to group one or more databases of the **same type** (like all your MySQL databases) under shared backup settings. It's a label you create to organize your backups, not necessarily tied to a specific client, website, or application. Choose a name that makes sense for how you want to manage your backups.
-   **Key Principle:** One project config = one database engine type (MySQL, MariaDB, or PostgreSQL).
-   **Run**: 
    -   `sudo cp /etc/db_backups/conf.d.sample/project.conf.sample /etc/db_backups/conf.d/project.conf`
    -   `sudo nano /etc/db_backups/conf.d/project.conf`
-   **Security:** Restrict access since this file contains DB passwords:
    -   `sudo chmod 600 /etc/db_backups/conf.d/project.conf`
    -   `sudo chown root:root /etc/db_backups/conf.d/project.conf`
-   **Example Fields:**
    

```
# Unique project name
PROJECT_NAME="my_project"

# List of Databases for this project (space-separated strings in a bash array)
DBS_TO_BACKUP=("db1" "db2")

# Database Type
# Supported: "mysql", "mariadb",  "postgres"
DB_TYPE="mysql"

# Database Credentials
DB_USER="root"
DB_PASSWORD="mypassword"

# --- Backup Target & Storage ---
# BACKUP_TYPE: Specifies where to store backups for this project.
# Supported: "local", "cloud", "both"."
BACKUP_TYPE="both"

# Cloud Storage Settings (Required if BACKUP_TYPE is "cloud" or "both")
# Supported: "s3", "r2"
CLOUD_STORAGE_PROVIDER="s3"

# Bucket Name
S3_BUCKET_NAME="db-backups"

# S3 Path
S3_PATH="db_backups_server01"

# --- Frequency Enablement ---
# For each backup frequency, set to "on" to enable backups for THIS project.
BACKUP_FREQUENCY_MINUTELY="on"
BACKUP_FREQUENCY_HOURLY="on"
BACKUP_FREQUENCY_DAILY="on"
BACKUP_FREQUENCY_WEEKLY="on"
BACKUP_FREQUENCY_MONTHLY="on"

# --- Time To Live (TTL) / Retention Settings ---
# Define how long to keep backups for each frequency enabled above.
# Format: <number><unit> (m=minutes, h=hours, d=days, w=weeks, M=months, y=years)
# Example: "60m", "24h", "7d", "4w", "6M", "1y".

# Keep minutely backups for 2 hours
TTL_MINUTELY_BACKUP="120m"  
# Keep hourly backups for 24 hours (1 day)
TTL_HOURLY_BACKUP="24h"     
# Keep daily backups for 14 days (2 weeks)
TTL_DAILY_BACKUP="14d"      
# Keep weekly backups for 5 weeks
TTL_WEEKLY_BACKUP="5w"      
# Keep monthly backups for 12 months (1 year)
TTL_MONTHLY_BACKUP="12M"    

# ----- Advanced Settings (Optional) -----
#
# -- Settings for Cloudflare R2 --

# aws cli
# Define the profile name for AWS CLI that connects to Cloudflare R2
# R2_AWS_PROFILE_NAME="r2"

# s3cmd
# Define the path to config file needed by S3cmd to connect to Cloudflare R2
# R2_S3CMD_CONFIG_PATH="/root/.s3cfg_r2"


# -- Override Default Local Backup Location --
# By default, LOCAL_BACKUP_ROOT is /var/backups/db_backups/
# Uncomment and set this if you need a custom absolute path for this project's local backups.
# LOCAL_BACKUP_ROOT="/opt/custom_backup_location/my_project_backups"
#
# Override Default Temporary Directory:
# By default, TEMP_DIR is /var/cache/db_backups/PROJECT_NAME_temp/
# Uncomment and set this if you need a custom absolute path for this project's temporary files.
# TEMP_DIR="/opt/custom_temp_location/my_project_temp"

# ==============================================================================
# End of Sample Project Configuration
# ==============================================================================
```

#### 5.1.1  Project Grouping Rules:

Building on the concept of Project Config Files, here are the rules for how you should group your databases within these projects:

-   Each project configuration file is designed to manage backups for databases of a **single type** (e.g., all MySQL databases, or all PostgreSQL databases). This is because different database systems require specific tools and commands for dumping their data.
-   If you have a group of related databases (like those for a specific client or application) that use _different_ database engines, you'll need a separate project config file for each engine type. For example:
    -   WordPress on MariaDB → `wordpress_mariadb.conf`
    -   n8n on PostgreSQL → `n8n_postgresql.conf`
    -   Mautic on MySQL → `mautic_mysql.conf`
-   Conversely, if you have multiple databases that share the _same_ engine, you can group them under a single project config file. For instance, if both your WordPress and Mautic installations use MariaDB, they could both be included in a `websites_mariadb.conf` file.
-   **Important Note on Backup Retention (TTL):** If you configure multiple project files to save backups to the _exact same storage location_ (e.g., the same S3 bucket path), be aware that their automatic cleanup routines (based on TTL) might interfere with each other. This could lead to backups being deleted sooner than intended by one project's settings if another project's settings have a shorter retention period.

> **Limitation**
> If projects share the same backup location, their automatic cleanup routines (based on TTL) might interfere with each other.
> To prevent this, it's crucial to use identical TTL values across all project configurations that share the same backup directory.

### 5.2 Master Manifest Config File
After we have at least one project configuration file, we can now enable it. To do this, we need to set the Master Manifest Config.

-   **Path:** `/etc/db_backups/db_backups.conf`
-   **Purpose:** Enumerates which **projects** to process.
-   **Contents:** Only include statements, one per project:
-   **Run:** 
    -   `sudo cp /etc/db_backups/db_backups.conf.sample /etc/db_backups/db_backups.conf`
    -   `sudo nano /etc/db_backups/db_backups.conf`
-   **Enable/Disable:** Remove/add # before an include line to enable or disable a project's backups.
-   **Isolation:** Each included project runs in its own subshell; global variables here do not leak.

```
# /etc/db_backups/db_backups.conf
include /etc/db_backups/conf.d/my_project.conf;
# include /etc/db_backups/conf.d/another_project.conf;
```
>  Add/Remove # before an include line to disable or enable a project's backups in the manifest.
    

### 5.3. Permissions & Security

-   **Root Execution:** All scripts **must** run as root (sudo) to access databases, write dumps, and enforce permissions.
-   **File Ownership:** Backup archives and config files are owned by root—only root may read or modify them.

### 5.4. How the System Works

Understanding the workflow will help you configure and use `db_backups` effectively:

#### Master Manifest as Project Controller
The **Master Manifest** (`/etc/db_backups/db_backups.conf`) acts like a master switch that controls which projects are active. Think of it as your project playlist:
- **Enabled projects** (uncommented `include` lines) will be processed when backups run
- **Disabled projects** (commented with `#`) will be completely ignored
- You can easily enable/disable entire projects by adding/removing the `#` comment

#### Individual Project Settings
Each project has its own configuration file (`/etc/db_backups/conf.d/project.conf`) that defines:
- Which databases to backup
- Database connection details  
- Storage preferences (local, cloud, or both)
- **Frequency preferences** for that specific project

#### Cronjob-Driven Execution
The system is designed to work with cronjobs that trigger wrapper scripts at different frequencies:
- `dbb-minutely.sh` - triggered every few minutes
- `dbb-hourly.sh` - triggered every hour  
- `dbb-daily.sh` - triggered once per day
- `dbb-weekly.sh` - triggered once per week
- `dbb-monthly.sh` - triggered once per month

#### Smart Frequency Filtering
Here's where it gets clever: **All projects share the same code**, but each project can choose which frequencies to participate in.

**Example Workflow:**
1. Your cronjob triggers `dbb-hourly.sh`
2. The script reads the Master Manifest and finds all enabled projects
3. For each enabled project, it checks that project's individual settings
4. If `BACKUP_FREQUENCY_HOURLY="off"` in a project's config, that project gets skipped for this hourly run
5. If `BACKUP_FREQUENCY_HOURLY="on"`, the project's databases get backed up

This means:
- **Project A** might backup every hour and daily (hourly=on, daily=on, weekly=off)
- **Project B** might only backup weekly and monthly (hourly=off, daily=off, weekly=on, monthly=on)  
- **Project C** might be completely disabled (commented out in Master Manifest)

#### Practical Benefits
- **Flexible scheduling:** Different projects can have different backup frequencies
- **Easy management:** Enable/disable entire projects without touching individual settings
- **Resource control:** Skip heavy backups during peak hours by adjusting frequency settings
- **Maintenance mode:** Quickly disable all backups by commenting out projects in the Master Manifest
    

## 6. Dependencies

| Package   | Purpose                                  |
| --------- | ---------------------------------------- |
| bash    | shell for running the scripts            |
| git     | cloning this repository                  |
| zip     | compressing dumps                        |
| bc      | arithmetic for TTL calculations (legacy) |
| aws-cli | uploading to cloud storage (S3/R2)       |
| s3cmd   | sync cloud bucket (S3/R2)                |
| snapd   | required to install aws-cli via snap  |

## 7. Prerequisites
### 7.1 General Dependencies
Git and Zip are prerequisites for the project to run, needed to pull the repository and to compress the database backup files.
```
sudo apt install git zip
```

### 7.2  AWS Account & S3 Bucket or Cloudflare Account & R2 Bucket (Optional)
If you want to save the backups on the cloud (highly recommended), you will need a working account. The project currently supports AWS S3 and Cloudflare R2 buckets.

🔸 **AWS S3** -- Create an Account and Bucket
Step 1: Sign Up for AWS
1. Go to https://aws.amazon.com
2. Click "Create an AWS Account"
3. Fill in your email, password, and account name
4. Enter payment info (required for usage, even with Free Tier)
5. Complete identity verification and select a support plan

Step 2: Set Up an S3 Bucket
1. Log in to the AWS Console: https://console.aws.amazon.com/
2. Search for S3 in the services search bar
3. Click "Create bucket"
4. Fill in:
    - Bucket name (must be globally unique)
    - Region
    - Configure options as needed (default is fine for most)
5. Click "Create bucket"

Step 3: Get Access Credentials
1. Go to IAM > Users
2. Create a new user with programmatic access
3. Attach a policy like AmazonS3FullAccess
4. Save your **Access Key ID** and **Secret Access Key**

🔸 **Cloudflare R2** -- Create an Account and Bucket
Step 1: Create a Cloudflare Account
1. Go to https://dash.cloudflare.com
2. Click "Sign Up"
3. Enter your email and password, verify your email
4. Enter payment info (required for R2, even with Free Tier)

Step 2: Set Up R2
1. Go to R2 Object Storage (you can search in the dashboard)
2. Click "Create bucket"
3. Enter a Bucket name
4. (Optional) Set public/private permissions

Step 3: Generate R2 API Token
1. Go to R2 Object Storage Overview > API
2. Click "API"
3. Choose "Use R2 with APIs"
4. Save the given Account ID and URL for future reference, pick "S3 Compatible API" and click on "Create an API token"
5. This will send you to Manage API Token for R2, click on "Create Account API Token"
6. Create bucket name and permissions (note that db_backups requires write permission)
7. Click on "Create Account API Token"
8. Securely save all the info for future reference (Token value, Access Key ID, Secret Access Key, URL endpoint)


### 7.3 Install AWS CLI

```
sudo snap install aws-cli --classic
aws configure
```
Provide your access key, secret key, and default region when prompted.

### 7.4 Install S3cmd

```
sudo apt install s3cmd
s3cmd --configure
```

Enter your credentials to create `~/.s3cfg`.

### 7.5 Configuring Cloudflare R2 (Optional)

If you prefer to use Cloudflare R2 instead of AWS S3, you'll need to configure both AWS CLI and S3cmd with special R2-specific settings. Unlike AWS S3, R2 requires custom endpoints and profiles.

#### 7.5.1 AWS CLI Configuration for R2

**Step 1: Create an R2-Specific AWS CLI Profile**

You can access Cloudflare R2 with the AWS CLI by creating a dedicated profile pointing to your R2 endpoint. Once set up, standard AWS CLI S3 commands work seamlessly against R2.

Run the interactive setup to capture your R2 credentials:
```bash
sudo aws configure --profile r2
```
Where 'r2' is the profile name (you can choose any name you prefer).

When prompted, enter:
- **AWS Access Key ID:** `your-r2-access-key-id` (32-character hex string, e.g., `e1506511492856e02e36aa47e66b3b68`)
- **AWS Secret Access Key:** `your-r2-secret-access-key` (64-character hex string, e.g., `9606eb769f01b1ba468d6a32cce7e0118ea0c72730e831cc44cd62c3e20f18ba`)
- **Default region name:** `auto`
- **Default output format:** `json` (or press Enter for default)

**Step 2: Configure the R2 Endpoint**

To avoid errors, you need to add your R2 endpoint under the r2 profile configuration:

```bash
sudo su
cd ~/.aws
sudo nano config
```

Add the endpoint configuration to the file:
```ini
[default]
region = us-east-1

[profile r2]
region = auto
endpoint_url = https://your-account-id.r2.cloudflarestorage.com
```

Replace `your-account-id` with your actual Cloudflare account ID (32-character hex string, e.g., `957ba64b82843e3ee1a7a08aaf0fd92c`) from your R2 dashboard.

**Step 3: Test Your R2 Configuration**

Test by listing objects in your R2 bucket:
```bash
sudo aws s3 ls s3://your-r2-bucket-name --profile r2
```

Make sure you have some files in the bucket for testing.

#### 7.5.2 S3cmd Configuration for R2

**Step 1: Create R2 Profile for S3cmd**

Create a separate configuration file for R2:
```bash
sudo su
cd
sudo s3cmd --configure -c ~/.s3cfg_r2
```

Where `~/.s3cfg_r2` is the R2-specific configuration file.

When prompted, enter:
- **Access Key:** `your-r2-access-key-id` (32-character hex string, e.g., `e1506511492856e02e36aa47e66b3b68`)  
- **Secret Key:** `your-r2-secret-access-key` (64-character hex string, e.g., `9606eb769f01b1ba468d6a32cce7e0118ea0c72730e831cc44cd62c3e20f18ba`)
- **Default Region:** `auto`
- **S3 Endpoint:** `your-account-id.r2.cloudflarestorage.com` (without https://, e.g., `957ba64b82843e3ee1a7a08aaf0fd92c.r2.cloudflarestorage.com`)
- **DNS-style bucket+hostname:port template:** `%(bucket)s.your-account-id.r2.cloudflarestorage.com` (e.g., `%(bucket)s.957ba64b82843e3ee1a7a08aaf0fd92c.r2.cloudflarestorage.com`)

Note: `%(bucket)s.` is a required placeholder. For the rest of the prompted parameters, you can use defaults by pressing Enter.

**Step 2: Handle Expected Configuration Test Error**

During configuration, you may encounter:
```
ERROR: Test failed: 501
```

This is expected behavior. Cloudflare R2 intentionally rejects S3 ListBuckets calls that include unsupported query parameters with an HTTP 501 NotImplemented response. The s3cmd configuration test includes these parameters, so it fails predictably.

**This failure does not indicate a DNS or credential problem.**

**Step 3: Verify R2 S3cmd Configuration**

Ignore the 501 error from the configuration test. Instead, verify your setup by targeting a specific bucket:
```bash
sudo s3cmd -c ~/.s3cfg_r2 ls s3://your-r2-bucket-name
```

#### 7.5.3 Project Configuration for R2

When using R2, update your project configuration file (`/etc/db_backups/conf.d/project.conf`) to include these R2-specific settings:

```bash
# Cloud Storage Settings
CLOUD_STORAGE_PROVIDER="r2"

# R2-specific configurations (uncomment and configure)
R2_AWS_PROFILE_NAME="r2"
R2_S3CMD_CONFIG_PATH="/root/.s3cfg_r2"
```

### 7.6 General Dependencies

```
sudo apt install git zip
```
---

## 8. Test

You can run a manual backup to verify everything works:

`sudo /usr/local/sbin/db_backups/dbb-tester.sh`

> The tester script uses hourly frequency

## 9. Usage

After running a test, you can proceed to create cronjobs:

Example:

```
# Hourly backup
1 * * * * /usr/local/sbin/db_backups/dbb-hourly.sh >> /var/log/db_backups/hourly.log
```

#### Cronjobs
`sudo crontab -e`

Set up cron entries for each required frequency:

```
# Every 30 minutes
*/30 * * * * /usr/local/sbin/db_backups/dbb-minutely.sh \
  >> /var/log/db_backups/01.minutely.log
# Every hour at 01 minute
1 * * * * /usr/local/sbin/db_backups/dbb-hourly.sh \
  >> /var/log/db_backups/02.hourly.log 
# Every day at 04:03
3 4 * * * /usr/local/sbin/db_backups/dbb-daily.sh \
  >> /var/log/db_backups/03.daily.log 
# Every week on Monday at 00:02
2 0 * * MON /usr/local/sbin/db_backups/dbb-weekly.sh \
  >> /var/log/db_backups/04.weekly.log 
# Every month at 01:07
7 1 1 * * /usr/local/sbin/db_backups/dbb-monthly.sh \
  >> /var/log/db_backups/05.monthly.log
```

Wrapper scripts exist for all frequencies (minutely, daily, etc.).

## 10. Uninstall

To remove the tool while keeping existing backups and logs:

```
sudo /usr/local/sbin/db_backups/uninstall.sh
```

## Directory Layout

-   **/usr/local/sbin/db_backups/** – installed scripts and libraries
-   **/etc/db_backups/** – main manifest and project configs
-   **/var/backups/db_backups/** – default local backup location
-   **/var/log/db_backups/** – cron and tool logs

## License & Copyright

This project is licensed under the GPL v3 License - see the [LICENSE](LICENSE) file for details.

**Copyright © 2025 Alejandro Capuro Meyer**  
All rights reserved. This software is provided under the terms of the GPL v3 license.

**Author:** Alejandro Capuro Meyer  
**Project Repository:** https://github.com/capuromeyer/db_backups

### Development Acknowledgment

This project was developed with the assistance of various AI tools including Gemini, ChatGPT, Claude, Jules, Firebase, and others. The project lead, architecture, logic design, debugging, testing, refactoring decisions, and overall direction were provided by the author. AI tools were used as coding assistants to implement the specified requirements and logic under human guidance and supervision.

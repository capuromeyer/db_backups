# db_backups

## 1. Version

Project Version: **1.0.0**

## 2. About

**db_backups** is a collection of Bash scripts that create and manage MySQL, MariaDB, PostgreSQL and MongoDB backups.  Backups are organised by frequency (minutely, hourly, daily, weekly and monthly) and can be uploaded to AWS S3 or any S3‑compatible provider.  Old archives are automatically removed based on a configurable TTL.

## 3. Quick Guide

Install the tool with the online installer and then run a backup manually:

```bash
curl -sSL https://raw.githubusercontent.com/capuromeyer/db_backups/main/online_install.sh | sudo bash
sudo /usr/local/sbin/db_backups/run_backup.sh --frequency hourly
```

## 4. Installation

### Using the online installer
Run the one‑liner above as root.  It installs dependencies, copies the scripts into `/usr/local/sbin/db_backups` and places sample config files under `/etc/db_backups`.

### Manual installation
1. Install the dependencies listed below using your package manager.
2. Clone this repository:
   ```bash
   sudo git clone https://github.com/capuromeyer/db_backups.git /opt/db_backups
   ```
3. Copy the scripts:
   ```bash
   sudo mkdir -p /usr/local/sbin/db_backups
   sudo cp -r /opt/db_backups/staging_root/usr/local/sbin/db_backups/* /usr/local/sbin/db_backups
   ```
4. Copy the configuration templates:
   ```bash
   sudo mkdir -p /etc/db_backups/conf.d /etc/db_backups/conf.d.sample
   sudo cp /opt/db_backups/staging_root/etc/db_backups/db_backups.conf /etc/db_backups/
   sudo cp /opt/db_backups/staging_root/etc/db_backups/conf.d.sample/* /etc/db_backups/conf.d.sample/
   ```

## 5. Dependencies

| Package   | Purpose                                   |
|-----------|-------------------------------------------|
| `bash`    | shell for running the scripts             |
| `git`     | cloning this repository                   |
| `zip`     | compressing dumps                         |
| `bc`      | arithmetic for TTL calculations           |
| `aws-cli` | uploading to S3                           |
| `s3cmd`   | alternative S3 client                     |
| `snapd`   | required if installing aws-cli via snap   |

### 5.1 Install AWS CLI
```bash
sudo snap install aws-cli --classic
aws configure
```
Provide your access key, secret key and default region when prompted.

### 5.2 Install S3cmd
```bash
sudo apt install s3cmd
s3cmd --configure
```
Enter your credentials to create `~/.s3cfg`.

### 5.3 Install Remaining Dependencies
```bash
sudo apt install git zip bc
```

## 6. etc/config files
Edit `/etc/db_backups/db_backups.conf` to enable projects and set paths.  Per‑project configs live in `/etc/db_backups/conf.d/`.

## 7. Set Execute Permission
Ensure all scripts are executable:
```bash
sudo chmod +x /usr/local/sbin/db_backups/*.sh /usr/local/sbin/db_backups/lib/*.sh
```

## 8. Test
Run a manual backup to verify everything works:
```bash
sudo /usr/local/sbin/db_backups/run_backup.sh --frequency minutely
```

## 9. Cronjobs
Create cron entries for the frequencies you use.  Example for hourly backups:
```bash
1 * * * * /usr/local/sbin/db_backups/hourly.sh >> /var/log/db_backups/hourly.log
```

A collection of Bash scripts to automate database backups with optional cloud synchronization. Supported databases include MySQL, MariaDB, PostgreSQL and MongoDB. Backups are organized by frequency (minutely, hourly, daily, weekly, monthly) and old archives are cleaned up automatically based on configurable TTL values.

## Features
- Local dumps compressed with `zip`
- Optional upload to AWS S3 or compatible providers
- Automatic cleanup of expired backups
- Cron-friendly wrapper scripts for each frequency
- Modular library structure for easy extension

## Installation
Run the installer as root. It clones the repository, installs required packages (AWS CLI, s3cmd, zip, bc) and sets up directories under `/usr/local/sbin/db_backups` and `/etc/db_backups`.

```bash
curl -sSL https://raw.githubusercontent.com/capuromeyer/db_backups/main/online_install.sh | sudo bash
```

After installation, review `/etc/db_backups/db_backups.conf` and the sample files in `/etc/db_backups/conf.d.sample`. Copy samples to `/etc/db_backups/conf.d/` and adjust for your projects.

## Usage
Run a backup manually with `run_backup.sh`:

```bash
sudo /usr/local/sbin/db_backups/run_backup.sh --frequency hourly
```

For automated operation add cron jobs. Example:

```bash
# Hourly backup
1 * * * * /usr/local/sbin/db_backups/hourly.sh >> /var/log/db_backups/hourly.log
```

Wrapper scripts exist for all frequencies (`minutely.sh`, `daily.sh`, etc.).

## Uninstall
To remove the tool while keeping existing backups and logs:

```bash
sudo /usr/local/sbin/db_backups/uninstall.sh
```

## Directory Layout
- `/usr/local/sbin/db_backups/` – installed scripts and libraries
- `/etc/db_backups/` – main manifest and project configs
- `/var/backups/db_backups/` – default local backup location
- `/var/log/db_backups/` – cron and tool logs

## License
See [LICENSE](LICENSE) for details.


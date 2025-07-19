# db_backups

A modular Bash toolkit for automated database backups with optional cloud synchronization.

## Version

**1.0.0** – major refactor of the original legacy scripts.

## Overview

`db_backups` provides command line utilities to dump MySQL/MariaDB databases on a schedule and optionally upload the results to S3 compatible storage. Each project has its own configuration file and the toolkit orchestrates pre‑flight checks, compression, cleanup and cloud synchronization.

Main components include:

- `run_backup.sh` – entry point that accepts `--frequency` (minutely, hourly, daily, weekly, monthly).
- `global-runner.sh` – reads the manifest, filters projects by frequency and triggers backups.
- Library scripts in `lib/` handling database dumps, file operations and cloud uploads.
- Installation helpers under `online_install.sh` and an `uninstall.sh` script.

## Installation

The recommended way is to run the online installer. It creates standard directories under `/usr/local/sbin/db_backups`, `/etc/db_backups` and `/var/backups/db_backups`.

```bash
curl -sSL https://raw.githubusercontent.com/capuromeyer/db_backups/main/online_install.sh | sudo bash
```

The installer copies all scripts, installs dependencies (AWS CLI, s3cmd, zip, bc) and places a sample configuration at `/etc/db_backups/db_backups.conf.sample`.

## Configuration

Edit `/etc/db_backups/db_backups.conf` to include project configuration files stored under `/etc/db_backups/conf.d/`. Each project file defines database credentials, backup type (local, cloud or both), S3 bucket information and TTLs for each frequency.

Example snippet:

```bash
# /etc/db_backups/conf.d/my_project.conf
PROJECT_NAME="my_project"
DB_TYPE="mysql"
DB_USER="dbuser"
DB_PASSWORD="secret"
DBS_TO_BACKUP=("db1" "db2")
BACKUP_TYPE="both"
S3_BUCKET_NAME="my-backups-bucket"
BACKUP_FREQUENCY_HOURLY="on"
```

## Running Backups Manually

After configuring a project, a backup can be triggered manually. For example, to run the hourly cycle:

```bash
sudo /usr/local/sbin/db_backups/run_backup.sh --frequency hourly
```

Logs are written to `/var/log/db_backups` and local backups to `/var/backups/db_backups/<frequency>/`.

## Scheduling with Cron

Automate execution by creating cron entries. Below is a common schedule:

```cron
# Every hour
1 * * * * /usr/local/sbin/db_backups/run_backup.sh --frequency hourly >> /var/log/db_backups/hourly.log

# Daily at 03:00
0 3 * * * /usr/local/sbin/db_backups/run_backup.sh --frequency daily >> /var/log/db_backups/daily.log
```

## Uninstallation

To remove all installed scripts and configuration files run:

```bash
sudo /usr/local/sbin/db_backups/uninstall.sh
```

Backup data and logs remain on disk until deleted manually.

## Directory Layout

- `/usr/local/sbin/db_backups/` – core scripts and libraries
- `/etc/db_backups/` – main manifest and project configs
- `/var/backups/db_backups/` – local backup storage
- `/var/cache/db_backups/` – temporary files
- `/var/log/db_backups/` – log files for cron execution

## Development & Testing

A helper script `test-runner.sh` exercises the new workflow for development purposes. It sources the same libraries as the main runner and can be used to validate configuration before enabling cron jobs.

## License

This project is distributed under the terms of the GNU General Public License v2.0. See the `LICENSE` file for details.


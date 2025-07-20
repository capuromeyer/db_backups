# db_backups

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

# Backup Tool

A simple and universal backup & restore tool for Docker Compose-based projects.

---

## Installation

### 1. Download the latest `.deb` release

Visit the [Releases](https://github.com/jordimock/backup-tool/releases) page and download the latest `.deb` package, or use:

```bash
wget https://github.com/jordimock/backup-tool/releases/download/v0.1/limbo-backup-tool_0.1_all.deb
```

> Replace the version if needed.

### 2. Install dependencies

Make sure the required system packages are installed:

```bash
sudo apt-get update
sudo apt-get install -y \
  bash \
  tar \
  gzip \
  gnupg \
  rclone \
  systemd \
  coreutils \
  rsync \
  openssh-client
```

### 3. Install the package

```bash
sudo dpkg -i limbo-backup-tool_0.1_all.deb
```

---

### 4. Post-installation check

To confirm that the systemd timer is active:

```bash
systemctl status limbo-backup.timer
```

---

## Configuration

### Main configuration file

Global settings are defined in:

```
/etc/limbo-backup/backup.conf.bash
```

This file includes:

```bash
# === Global settings ===
BACKUP_NAME="limbo-backup"
ARTEFACTS_DIR="/var/lib/limbo-backup/artefacts"

# === Module-specific settings ===

# rsync
RSYNC_ARTEFACTS_DIR="$ARTEFACTS_DIR/backup-rsync"

# tar.gz
TAR_ARTEFACTS_DIR="$ARTEFACTS_DIR/backup-tar"

# gpg encryption
GPG_ARTEFACTS_DIR="$ARTEFACTS_DIR/backup-gpg"
GPG_DELETE_TAR_SOURCE=1
GPG_FINGERPRINT="EXAMPLE_GPG_KEY_FINGERPRINT"

# rclone upload (SFTP example)
RCLONE_PROTO="sftp"
RCLONE_HOST="your.remote.host"
RCLONE_PORT="22"
RCLONE_USER="backupuser"
RCLONE_PASS="your_encrypted_or_app_password"
RCLONE_REMOTE_PATH="/backups/limbo"
```

Modify values according to your environment.

> This file is treated as a conffile: it will not be overwritten or removed during package upgrades or uninstallation.

---

### Task definitions

Individual backup tasks are stored in:

```
/etc/limbo-backup/rsync.conf.d/
```

Each file describes one backup job and follows this format:

```bash
CMD_BEFORE_BACKUP="docker compose --project-directory /docker/your-app stop"
CMD_AFTER_BACKUP="docker compose --project-directory /docker/your-app start"

INCLUDE_PATHS=(
  "/docker/your-app"
)

EXCLUDE_PATHS=(
  "/docker/your-app/tmp"
  "/docker/your-app/cache"
)
```

You can create multiple `.bash` files in this directory. They will be executed in alphanumeric order.

---


## Uninstall

To remove the package but keep the configuration:

```bash
sudo dpkg -r limbo-backup-tool
```

To completely purge the package and its configuration:

```bash
sudo dpkg --purge limbo-backup-tool
```

---

## Bakup usage

### Manual backup

To run all configured backup tasks immediately:

```bash
sudo systemctl start limbo-backup.service
```

This will:

1. Load global configuration from `/etc/limbo-backup/backup.conf.bash`
2. Execute all task files from `/etc/limbo-backup/rsync.conf.d/` in alphanumeric order
3. Apply all enabled plugins (e.g., rsync, tar, gpg, rclone)

Logs are written to `journalctl` via systemd when executed as a service.

---

### Check logs

To inspect logs of the systemd timer or service:

```bash
journalctl -u limbo-backup.timer
journalctl -u limbo-backup.service
```


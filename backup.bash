#!/bin/bash
set -e




# ==========================================
# SCRIPT
# ==========================================

# Get absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
BACKUP_DIR="${PROJECT_ROOT}/backups"

# Config file expected at PROJECT_ROOT/backup-tool.config.bash
CONFIG_FILE="${PROJECT_ROOT}/backup-tool.config.bash"

# Validate config presence
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Missing config file at ${CONFIG_FILE}" >&2
    echo "Copy backup-tool/backup-tool.config.bash to backup-tool.config.bash and configure it." >&2
    exit 1
fi

# Source the config
source "$CONFIG_FILE"

# Validate GPG fingerprint if provided
if [ -n "$GPG_FINGERPRINT" ]; then
    gpg --list-keys "$GPG_FINGERPRINT" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: GPG key with fingerprint '$GPG_FINGERPRINT' not found in keyring."
        echo
        echo "Available GPG keys:"
        gpg --list-keys --with-colons | grep '^fpr' | cut -d: -f10
        exit 1
    fi
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

#
NO_STOP=0
NO_START=0

# Parse flags
for arg in "$@"; do
    case "$arg" in
        --no-stop)
            NO_STOP=1
            ;;
        --no-start)
            NO_START=1
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

# Initialize variables after validation
DATE=$(date +"%Y%m%d")
ARCHIVE_NAME="${DATE}.tar.gz"
ENCRYPTED_NAME="${DATE}.${GPG_FINGERPRINT}.gpg"
TMP_DIR=$(mktemp -d -t backup-tmp-XXXXXXXXXXXXXXXX)

# Clean old backup files with the same names
echo "Cleaning up old backup files..."
rm -f "${BACKUP_DIR}/${ARCHIVE_NAME}"
rm -f "${BACKUP_DIR}/${ENCRYPTED_NAME}"

# Stop Docker containers
if [ "$NO_STOP" -eq 0 ]; then
    echo "Stopping containers..."
    docker compose --project-directory "$PROJECT_ROOT" down
else
    echo "Skipping stopping containers (--no-stop enabled)"
fi

# Making backup
echo "Preparing backup structure..."
mkdir -p "${TMP_DIR}/data"

echo "Copying config..."
cp "${CONFIG_FILE}" "${TMP_DIR}/backup-tool.config.bash"

echo "Copying data..."
for item in "${TO_BACKUP[@]}"; do
    cp -a "${PROJECT_ROOT}/${item}" "${TMP_DIR}/data/"
done

echo "Creating archive ${ARCHIVE_NAME} with required structure..."
tar -czf "${BACKUP_DIR}/${ARCHIVE_NAME}" -C "${TMP_DIR}" .

echo "Cleaning up temporary files..."
rm -rf "${TMP_DIR}"


# Restart Docker containers
if [ "$NO_START" -eq 0 ]; then
    echo "Starting Docker containers..."
    docker compose --project-directory "$PROJECT_ROOT" up -d
else
    echo "Skipping starting containers (--no-start enabled)"
fi


# Check if archive was created
if [ ! -f "${BACKUP_DIR}/${ARCHIVE_NAME}" ]; then
    echo "Error: Backup archive was not created." >&2
    exit 1
fi

# Optional encryption
if [ -n "$GPG_FINGERPRINT" ]; then
    echo "Encrypting archive with recipient fingerprint ${GPG_FINGERPRINT}..."
    
    gpg --trust-model always \
        --output "${BACKUP_DIR}/${ENCRYPTED_NAME}" \
        --encrypt \
        --recipient "$GPG_FINGERPRINT" \
        "${BACKUP_DIR}/${ARCHIVE_NAME}"

    if [ $? -eq 0 ]; then
        rm "${BACKUP_DIR}/${ARCHIVE_NAME}"
        echo "Archive successfully encrypted as ${ENCRYPTED_NAME}."
    else
        echo "Error encrypting the archive."
        exit 1
    fi
fi

echo "Backup completed successfully. Backup file located in ${BACKUP_DIR}"

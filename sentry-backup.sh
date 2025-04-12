#!/bin/bash

# Sentry Backup Script
# Author: Thiago T Faioli a.k.a 0xttfx - <faioli@0x.systems>
# Version: 1.1.0
# Date: 2025-04-11
# Description: Creates a complete backup of Sentry self-hosted instance

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Function to list existing backups
list_backups() {
    local backup_dir="$1"
    if [ -d "$backup_dir" ]; then
        echo "Backups disponíveis em $backup_dir:"
        echo "----------------------------------------"
        ls -l "$backup_dir" | grep '^d' | awk '{print $6" "$7" "$8" - "$9}' | sort -r
        echo "----------------------------------------"
    else
        echo "Nenhum backup encontrado em $backup_dir"
    fi
}

# Function to log messages
log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Function to log errors
error() {
    log "$1" "ERROR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "${ERROR_LOG_FILE}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a directory is writable
is_writable() {
    local dir="$1"
    [ -w "$dir" ] || return 1
}

# Function to handle cleanup on script exit
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        error "Backup failed with exit code: $exit_code"
    else
        log "Backup completed successfully"
    fi
    exit $exit_code
}

# Set up trap for cleanup
trap cleanup EXIT

# Default backup directory
DEFAULT_BACKUP_DIR="/backup/sentry"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -l|--list)
            list_backups "$DEFAULT_BACKUP_DIR"
            exit 0
            ;;
        -h|--help)
            echo "Uso: $0 [opções]"
            echo "Opções:"
            echo "  -d, --directory DIR  Especifica o diretório de backup"
            echo "  -l, --list          Lista backups existentes"
            echo "  -h, --help          Mostra esta ajuda"
            exit 0
            ;;
        *)
            echo "Opção inválida: $1"
            echo "Use -h ou --help para ver as opções disponíveis"
            exit 1
            ;;
    esac
done

# If backup directory is not specified, ask the user
if [ -z "${BACKUP_DIR:-}" ]; then
    read -p "Digite o diretório para backup [padrão: $DEFAULT_BACKUP_DIR]: " user_input
    BACKUP_DIR="${user_input:-$DEFAULT_BACKUP_DIR}"
fi

# Create timestamp and paths
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"
LOG_FILE="${BACKUP_PATH}/backup.log"
ERROR_LOG_FILE="${BACKUP_PATH}/error.log"

# Create backup directory if it doesn't exist
if ! mkdir -p "${BACKUP_PATH}"; then
    error "Failed to create backup directory: ${BACKUP_PATH}"
    exit 1
fi

# Check if backup directory is writable
if ! is_writable "${BACKUP_PATH}"; then
    error "Backup directory is not writable: ${BACKUP_PATH}"
    exit 1
fi

log "Starting Sentry backup process"

# Check if docker-compose is available
if ! command_exists docker-compose; then
    error "docker-compose is not installed"
    exit 1
fi

# Check if docker is running
if ! docker info >/dev/null 2>&1; then
    error "Docker daemon is not running"
    exit 1
fi

# 1. Create partial JSON backup
log "Creating partial JSON backup..."
if ! docker-compose run --rm -T -e SENTRY_LOG_LEVEL=CRITICAL web export > "${BACKUP_PATH}/sentry-backup.json" 2>> "${ERROR_LOG_FILE}"; then
    error "Failed to create partial JSON backup"
    exit 1
fi

# 2. Backup PostgreSQL using pg_dumpall
log "Creating PostgreSQL dump using pg_dumpall..."
PG_CONTAINER=$(docker-compose ps -q postgres)
if [ -n "$PG_CONTAINER" ]; then
    # Get PostgreSQL credentials from environment
    PG_USER=$(docker-compose exec -T postgres env | grep POSTGRES_USER= | cut -d'=' -f2)
    PG_PASSWORD=$(docker-compose exec -T postgres env | grep POSTGRES_PASSWORD= | cut -d'=' -f2)
    PG_DB=$(docker-compose exec -T postgres env | grep POSTGRES_DB= | cut -d'=' -f2)

    if [ -z "$PG_USER" ] || [ -z "$PG_PASSWORD" ] || [ -z "$PG_DB" ]; then
        error "Failed to get PostgreSQL credentials"
        exit 1
    fi

    # Create pg_dumpall backup
    if ! docker-compose exec -T postgres pg_dumpall -U "${PG_USER}" > "${BACKUP_PATH}/postgres-dumpall.sql" 2>> "${ERROR_LOG_FILE}"; then
        error "Failed to create PostgreSQL dump"
        exit 1
    fi
    
    # Compress the dump
    if ! gzip "${BACKUP_PATH}/postgres-dumpall.sql"; then
        error "Failed to compress PostgreSQL dump"
        exit 1
    fi
    log "PostgreSQL dump created successfully"
else
    error "PostgreSQL container not found"
    exit 1
fi

# 3. Backup all critical volumes
log "Backing up critical volumes..."

# List of critical volumes to backup
VOLUMES=(
    "sentry-data"
    "sentry-postgres"
    "sentry-redis"
    "sentry-kafka"
    "sentry-clickhouse"
    "sentry-symbolicator"
)

# Backup each volume
for volume in "${VOLUMES[@]}"; do
    log "Backing up volume: ${volume}"
    if ! docker run --rm -v "${volume}:/source" -v "${BACKUP_PATH}:/backup" alpine tar -czf "/backup/${volume}.tar.gz" -C /source . 2>> "${ERROR_LOG_FILE}"; then
        error "Failed to backup volume: ${volume}"
        exit 1
    fi
done

# 4. Backup project-specific volumes
log "Backing up project-specific volumes..."
while IFS= read -r volume; do
    if [ -n "$volume" ]; then
        log "Backing up volume: ${volume}"
        if ! docker run --rm -v "${volume}:/source" -v "${BACKUP_PATH}:/backup" alpine tar -czf "/backup/${volume}.tar.gz" -C /source . 2>> "${ERROR_LOG_FILE}"; then
            error "Failed to backup volume: ${volume}"
            exit 1
        fi
    fi
done < <(docker volume ls --filter name=sentry_self_hosted_sentry- --format "{{.Name}}")

# 5. Create a backup manifest
log "Creating backup manifest..."
cat > "${BACKUP_PATH}/backup-manifest.txt" << EOF
Backup created at: $(date)
Sentry Version: 25.3.0
Backup Type: Full
Contents:
- sentry-backup.json (Partial JSON backup)
- postgres-dumpall.sql.gz (PostgreSQL dump)
- Volume backups:
$(ls -1 "${BACKUP_PATH}"/*.tar.gz)
EOF

# Calculate backup size
BACKUP_SIZE=$(du -sh "${BACKUP_PATH}" | cut -f1)
log "Backup size: ${BACKUP_SIZE}"

# Verify backup integrity
log "Verifying backup integrity..."
for file in "${BACKUP_PATH}"/*.tar.gz; do
    if ! gzip -t "$file" 2>> "${ERROR_LOG_FILE}"; then
        error "Backup file integrity check failed: $file"
        exit 1
    fi
done

log "Backup completed successfully"
log "Backup stored in: ${BACKUP_PATH}" 

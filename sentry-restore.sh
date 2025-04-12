#!/bin/bash

# Sentry Restore Script
# Author: Thiago T Faioli a.k.a 0xttfx - <faioli@0x.systems>
# Version: 1.1.0
# Date: 2024-04-11
# Description: Restores a complete backup of Sentry self-hosted instance

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Default backup directory
DEFAULT_BACKUP_DIR="/backup/sentry"

# Function to list available backups
list_backups() {
    local backup_dir="$1"
    if [ -d "$backup_dir" ]; then
        echo "Backups disponíveis em $backup_dir:"
        echo "----------------------------------------"
        local backups=()
        while IFS= read -r line; do
            backups+=("$line")
            echo "${#backups[@]}) $line"
        done < <(ls -l "$backup_dir" | grep '^d' | awk '{print $6" "$7" "$8" - "$9}' | sort -r)
        echo "----------------------------------------"
        echo "${#backups[@]}) Sair"
        echo "----------------------------------------"
        return "${#backups[@]}"
    else
        echo "Nenhum backup encontrado em $backup_dir"
        return 0
    fi
}

# Function to select backup
select_backup() {
    local backup_dir="$1"
    local max_backups="$2"
    
    while true; do
        read -p "Digite o número do backup para restaurar (1-$max_backups) ou $max_backups para sair: " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$max_backups" ]; then
            if [ "$choice" -eq "$max_backups" ]; then
                echo "Operação cancelada pelo usuário"
                exit 0
            fi
            local selected_backup=$(ls -l "$backup_dir" | grep '^d' | awk '{print $9}' | sort -r | sed -n "${choice}p")
            echo "$backup_dir/$selected_backup"
            return
        else
            echo "Opção inválida. Por favor, escolha um número entre 1 e $max_backups"
        fi
    done
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

# Function to check if a file exists and is readable
is_readable() {
    local file="$1"
    [ -r "$file" ] || return 1
}

# Function to handle cleanup on script exit
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        error "Restore failed with exit code: $exit_code"
    else
        log "Restore completed successfully"
    fi
    exit $exit_code
}

# Set up trap for cleanup
trap cleanup EXIT

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Uso: $0 [opções]"
            echo "Opções:"
            echo "  -d, --directory DIR  Especifica o diretório de backup"
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
    read -p "Digite o diretório onde estão os backups [padrão: $DEFAULT_BACKUP_DIR]: " user_input
    BACKUP_DIR="${user_input:-$DEFAULT_BACKUP_DIR}"
fi

# List and select backup
echo "Listando backups disponíveis..."
list_backups "$BACKUP_DIR"
max_backups=$?
if [ "$max_backups" -eq 0 ]; then
    error "Nenhum backup encontrado em $BACKUP_DIR"
    exit 1
fi

BACKUP_PATH=$(select_backup "$BACKUP_DIR" "$max_backups")
LOG_FILE="${BACKUP_PATH}/restore.log"
ERROR_LOG_FILE="${BACKUP_PATH}/restore-error.log"

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

# Check if backup directory exists and is readable
if [ ! -d "${BACKUP_PATH}" ]; then
    error "Backup directory ${BACKUP_PATH} does not exist"
    exit 1
fi

if ! is_readable "${BACKUP_PATH}"; then
    error "Backup directory is not readable: ${BACKUP_PATH}"
    exit 1
fi

log "Starting Sentry restore process"

# 1. Stop all Sentry services
log "Stopping Sentry services..."
if ! docker-compose down 2>> "${ERROR_LOG_FILE}"; then
    error "Failed to stop Sentry services"
    exit 1
fi

# 2. Restore critical volumes
log "Restoring critical volumes..."

# List of critical volumes to restore
VOLUMES=(
    "sentry-data"
    "sentry-postgres"
    "sentry-redis"
    "sentry-zookeeper"
    "sentry-kafka"
    "sentry-clickhouse"
    "sentry-symbolicator"
)

# Restore each volume
for volume in "${VOLUMES[@]}"; do
    BACKUP_FILE="${BACKUP_PATH}/${volume}.tar.gz"
    if [ -f "${BACKUP_FILE}" ]; then
        log "Restoring volume: ${volume}"
        # Remove existing volume if it exists
        docker volume rm "${volume}" 2>/dev/null || true
        # Create new volume
        if ! docker volume create "${volume}" 2>> "${ERROR_LOG_FILE}"; then
            error "Failed to create volume: ${volume}"
            exit 1
        fi
        # Restore data
        if ! docker run --rm -v "${volume}:/target" -v "${BACKUP_PATH}:/backup" alpine sh -c "rm -rf /target/* && tar -xzf /backup/${volume}.tar.gz -C /target" 2>> "${ERROR_LOG_FILE}"; then
            error "Failed to restore volume: ${volume}"
            exit 1
        fi
    else
        error "Backup file for volume ${volume} not found"
        exit 1
    fi
done

# 3. Restore project-specific volumes
log "Restoring project-specific volumes..."
for backup_file in "${BACKUP_PATH}"/sentry_self_hosted_sentry-*.tar.gz; do
    if [ -f "${backup_file}" ]; then
        volume_name=$(basename "${backup_file}" .tar.gz)
        log "Restoring volume: ${volume_name}"
        # Remove existing volume if it exists
        docker volume rm "${volume_name}" 2>/dev/null || true
        # Create new volume
        if ! docker volume create "${volume_name}" 2>> "${ERROR_LOG_FILE}"; then
            error "Failed to create volume: ${volume_name}"
            exit 1
        fi
        # Restore data
        if ! docker run --rm -v "${volume_name}:/target" -v "${BACKUP_PATH}:/backup" alpine sh -c "rm -rf /target/* && tar -xzf /backup/${volume_name}.tar.gz -C /target" 2>> "${ERROR_LOG_FILE}"; then
            error "Failed to restore volume: ${volume_name}"
            exit 1
        fi
    fi
done

# 4. Start Sentry services
log "Starting Sentry services..."
if ! docker-compose up -d 2>> "${ERROR_LOG_FILE}"; then
    error "Failed to start Sentry services"
    exit 1
fi

# Wait for services to be ready
log "Waiting for services to be ready..."
sleep 30

# 5. Restore PostgreSQL dump if available
if [ -f "${BACKUP_PATH}/postgres-dumpall.sql.gz" ]; then
    log "Restoring PostgreSQL dump..."
    # Get PostgreSQL credentials from environment
    PG_USER=$(docker-compose exec -T postgres env | grep POSTGRES_USER= | cut -d'=' -f2)
    PG_PASSWORD=$(docker-compose exec -T postgres env | grep POSTGRES_PASSWORD= | cut -d'=' -f2)
    
    if [ -z "$PG_USER" ] || [ -z "$PG_PASSWORD" ]; then
        error "Failed to get PostgreSQL credentials"
        exit 1
    fi
    
    # Decompress and restore the dump
    if ! gunzip -c "${BACKUP_PATH}/postgres-dumpall.sql.gz" | docker-compose exec -T postgres psql -U "${PG_USER}" -d postgres 2>> "${ERROR_LOG_FILE}"; then
        error "Failed to restore PostgreSQL dump"
        exit 1
    fi
    log "PostgreSQL dump restored successfully"
else
    error "PostgreSQL dump file not found"
    exit 1
fi

# 6. Restore partial JSON backup
if [ -f "${BACKUP_PATH}/sentry-backup.json" ]; then
    log "Restoring partial JSON backup..."
    if ! docker-compose run --rm -T web import < "${BACKUP_PATH}/sentry-backup.json" 2>> "${ERROR_LOG_FILE}"; then
        error "Failed to restore partial JSON backup"
        exit 1
    fi
else
    error "Partial JSON backup file not found"
    exit 1
fi

log "Restore completed successfully"
log "Please verify that all services are running correctly" 
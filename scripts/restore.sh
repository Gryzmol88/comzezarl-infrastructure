#!/bin/bash

set -e

LOG_FILE="logs/restore.log"
source scripts/common.sh
load_env

if [ -z "$1" ]; then
  log_error "Usage: ./scripts/restore.sh backups/YYYY-MM-DD-HHMM"
  exit 1
fi

BACKUP_DIR="$1"

require_directory "$BACKUP_DIR"
require_file "$BACKUP_DIR/backup-db.sql"
require_file "$BACKUP_DIR/backup-wp-files.tar.gz"

WP_VOLUME=$(docker volume ls --format "{{.Name}}" | grep "_comzezarl_wp_data$" | head -n 1)

if [ -z "$WP_VOLUME" ]; then
  log_error "Nie znaleziono wolumenu WordPress."
  exit 1
fi

log "========================================="
log "Restore started"
log "Backup directory: $BACKUP_DIR"
log "WordPress volume: $WP_VOLUME"
log "========================================="

log "Restoring WordPress files..."
docker run --rm \
  -v "$WP_VOLUME":/data \
  -v "$(pwd)/$BACKUP_DIR":/backup \
  alpine \
  sh -c "cd /data && tar xzf /backup/backup-wp-files.tar.gz"

log "Restoring database..."
cat "$BACKUP_DIR/backup-db.sql" | docker exec -i comzezarl-db mariadb \
  -u"$MYSQL_USER" \
  -p"$MYSQL_PASSWORD" \
  "$MYSQL_DATABASE"

log "Restarting containers..."
docker compose restart

log "Restore completed from: $BACKUP_DIR"
log "========================================="
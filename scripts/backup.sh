#!/bin/bash

set -e

LOG_FILE="logs/backup.log"
source scripts/common.sh
load_env

PROJECT_NAME=${PROJECT_NAME:-comzezarl}
PROJECT_VERSION=${PROJECT_VERSION:-1.0.0}
PROJECT_ENV=${PROJECT_ENV:-local}

BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-180}
BACKUP_REMOTE_ENABLED=${BACKUP_REMOTE_ENABLED:-false}
BACKUP_CREATE_MANIFEST=${BACKUP_CREATE_MANIFEST:-true}


START_TIME=$(date +%s)

BACKUP_ID=$(date +%Y-%m-%d-%H%M)
BACKUP_DIR="backups/$BACKUP_ID"

WP_VOLUME=$(docker volume ls --format "{{.Name}}" | grep "_comzezarl_wp_data$" | head -n 1)

if [ -z "$WP_VOLUME" ]; then
  log_error "Nie znaleziono wolumenu WordPress."
  exit 1
fi

mkdir -p "$BACKUP_DIR"

log "========================================="
log "Backup started"
log "Project: $PROJECT_NAME"
log "Version: $PROJECT_VERSION"
log "Environment: $PROJECT_ENV"
log "Backup ID: $BACKUP_ID"
log "Backup directory: $BACKUP_DIR"
log "WordPress volume: $WP_VOLUME"
log "========================================="

log "Creating database backup..."
docker exec comzezarl-db mariadb-dump \
  -u"$MYSQL_USER" \
  -p"$MYSQL_PASSWORD" \
  "$MYSQL_DATABASE" \
  > "$BACKUP_DIR/backup-db.sql"

log "Creating WordPress files backup..."
docker run --rm \
  -v "$WP_VOLUME":/data \
  -v "$(pwd)/$BACKUP_DIR":/backup \
  alpine \
  sh -c "cd /data && tar czf /backup/backup-wp-files.tar.gz ."

DB_SIZE=$(du -h "$BACKUP_DIR/backup-db.sql" | cut -f1)
WP_SIZE=$(du -h "$BACKUP_DIR/backup-wp-files.tar.gz" | cut -f1)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

DB_SHA256=$(sha256sum "$BACKUP_DIR/backup-db.sql" | awk '{print $1}')
WP_SHA256=$(sha256sum "$BACKUP_DIR/backup-wp-files.tar.gz" | awk '{print $1}')

HOSTNAME_VALUE=$(hostname)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

if [ "$BACKUP_CREATE_MANIFEST" = "true" ]; then
  log "Creating manifest.json..."

  cat > "$BACKUP_DIR/manifest.json" <<EOF
{
  "manifest_version": 1,
  "metadata": {
    "id": "$BACKUP_ID",
    "project": "$PROJECT_NAME",
    "project_version": "$PROJECT_VERSION",
    "environment": "$PROJECT_ENV",
    "created_at": "$(date -Iseconds)",
    "host": "$HOSTNAME_VALUE"
  },
  "docker": {
    "wordpress_volume": "$WP_VOLUME",
    "database": "$MYSQL_DATABASE",
    "git_commit": "$GIT_COMMIT"
  },
  "files": {
    "database": {
      "name": "backup-db.sql",
      "size": "$DB_SIZE",
      "sha256": "$DB_SHA256"
    },
    "wordpress": {
      "name": "backup-wp-files.tar.gz",
      "size": "$WP_SIZE",
      "sha256": "$WP_SHA256"
    }
  },
  "cloud": {
    "enabled": $BACKUP_REMOTE_ENABLED,
    "provider": null,
    "uploaded": false,
    "uploaded_at": null
  },
  "status": {
    "backup": "completed",
    "verified": false,
    "restored": false
  }
}
EOF
fi

log "Verifying backup..."
./scripts/verify-backup.sh "$BACKUP_DIR"

log "Removing backups older than ${BACKUP_RETENTION_DAYS} days..."
find backups \
  -mindepth 1 \
  -maxdepth 1 \
  -type d \
  -mtime +"$BACKUP_RETENTION_DAYS" \
  -exec rm -rf {} \;

if [ "$BACKUP_REMOTE_ENABLED" = "true" ]; then
  log "Uploading backup to cloud..."
  ./scripts/backup-cloud.sh "$BACKUP_DIR"
  log "Cloud upload completed."
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

VERIFICATION_RESULT="PASSED"

log "========================================="
log "Backup summary"
log "Project: $PROJECT_NAME"
log "Environment: $PROJECT_ENV"
log "Backup ID: $BACKUP_ID"
log "Database size: $DB_SIZE"
log "WordPress files size: $WP_SIZE"
log "Total size: $TOTAL_SIZE"
log "Verification: $VERIFICATION_RESULT"
log "Duration: ${DURATION}s"
log "Backup completed: $BACKUP_DIR"
log "========================================="
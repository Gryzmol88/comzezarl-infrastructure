#!/bin/bash

set -e

source .env

BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-180}
BACKUP_REMOTE_ENABLED=${BACKUP_REMOTE_ENABLED:-false}
BACKUP_CREATE_MANIFEST=${BACKUP_CREATE_MANIFEST:-true}

BACKUP_DIR="backups/$(date +%Y-%m-%d-%H%M)"

WP_VOLUME=$(docker volume ls --format "{{.Name}}" | grep "_comzezarl_wp_data$" | head -n 1)

if [ -z "$WP_VOLUME" ]; then
  echo "Nie znaleziono wolumenu WordPress."
  exit 1
fi

mkdir -p "$BACKUP_DIR"

echo "WordPress volume: $WP_VOLUME"

echo "Creating database backup..."
docker exec comzezarl-db mariadb-dump \
  -u"$MYSQL_USER" \
  -p"$MYSQL_PASSWORD" \
  "$MYSQL_DATABASE" \
  > "$BACKUP_DIR/backup-db.sql"

echo "Creating WordPress files backup..."
docker run --rm \
  -v "$WP_VOLUME":/data \
  -v "$(pwd)/$BACKUP_DIR":/backup \
  alpine \
  tar czf /backup/backup-wp-files.tar.gz /data

echo "Removing backups older than ${BACKUP_RETENTION_DAYS} days..."

if [ "$BACKUP_CREATE_MANIFEST" = "true" ]; then
  echo "Creating manifest.json..."
  DB_SIZE=$(du -h "$BACKUP_DIR/backup-db.sql" | cut -f1)
  WP_SIZE=$(du -h "$BACKUP_DIR/backup-wp-files.tar.gz" | cut -f1)
  TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
  DB_SHA256=$(sha256sum "$BACKUP_DIR/backup-db.sql" | awk '{print $1}')
  WP_SHA256=$(sha256sum "$BACKUP_DIR/backup-wp-files.tar.gz" | awk '{print $1}')
  BACKUP_ID=$(basename "$BACKUP_DIR")
  HOSTNAME_VALUE=$(hostname)
  GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
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

echo "Verifying backup..."
./scripts/verify-backup.sh "$BACKUP_DIR"

find backups \
  -mindepth 1 \
  -type d \
  -mtime +"$BACKUP_RETENTION_DAYS" \
  -exec rm -rf {} \;

if [ "$BACKUP_REMOTE_ENABLED" = "true" ]; then
  echo "Remote backup enabled."
  echo "Cloud upload will be implemented in the next step."
fi

echo "Backup completed: $BACKUP_DIR"
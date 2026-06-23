#!/bin/bash

set -e

source .env

BACKUP_DIR="backups/$(date +%Y-%m-%d-%H%M)"
WP_VOLUME="comzezarl-local_comzezarl_wp_data"

mkdir -p "$BACKUP_DIR"

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

echo "Backup completed: $BACKUP_DIR"
#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "Usage: ./restore.sh backups/YYYY-MM-DD-HHMM"
  exit 1
fi

BACKUP_DIR="$1"

if [ ! -f "$BACKUP_DIR/backup-db.sql" ]; then
  echo "Missing database backup: $BACKUP_DIR/backup-db.sql"
  exit 1
fi

if [ ! -f "$BACKUP_DIR/backup-wp-files.tar.gz" ]; then
  echo "Missing WordPress files backup: $BACKUP_DIR/backup-wp-files.tar.gz"
  exit 1
fi

source .env

WP_VOLUME=$(docker volume ls --format "{{.Name}}" | grep "_comzezarl_wp_data$" | head -n 1)

if [ -z "$WP_VOLUME" ]; then
  echo "Nie znaleziono wolumenu WordPress."
  exit 1
fi

echo "WordPress volume: $WP_VOLUME"

echo "Restoring WordPress files..."
docker run --rm \
  -v "$WP_VOLUME":/data \
  -v "$(pwd)/$BACKUP_DIR":/backup \
  alpine \
  tar xzf /backup/backup-wp-files.tar.gz -C /

echo "Restoring database..."
cat "$BACKUP_DIR/backup-db.sql" | docker exec -i comzezarl-db mariadb \
  -u"$MYSQL_USER" \
  -p"$MYSQL_PASSWORD" \
  "$MYSQL_DATABASE"

echo "Restarting containers..."
docker compose restart

echo "Restore completed from: $BACKUP_DIR"
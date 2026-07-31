#!/bin/bash

set -euo pipefail

LOG_FILE="logs/restore.log"

source scripts/common.sh
load_env

if [ -z "${1:-}" ]; then
    log_error "Usage: ./scripts/restore.sh backups/YYYY-MM-DD-HHMM [--force]"
    exit 1
fi

BACKUP_DIR="$1"
FORCE="${2:-}"

require_directory "$BACKUP_DIR"
require_file "$BACKUP_DIR/backup-db.sql"
require_file "$BACKUP_DIR/backup-wp-files.tar.gz"

WP_VOLUME=$(docker volume ls --format "{{.Name}}" | grep "_comzezarl_wp_data$" | head -n1)

if [ -z "$WP_VOLUME" ]; then
    log_error "Nie znaleziono wolumenu WordPress."
    exit 1
fi

SITE_SCHEME="${SITE_SCHEME:-http}"

WP_SITE_URL="${SITE_SCHEME}://${SITE_DOMAIN}"

OPTIONS_TABLE="${WORDPRESS_TABLE_PREFIX}options"

log "========================================="
log "Restore configuration"
log "Backup: $BACKUP_DIR"
log "Volume: $WP_VOLUME"
log "URL: $WP_SITE_URL"
log "========================================="

if [ "$FORCE" != "--force" ]; then
    echo
    echo "UWAGA!"
    echo "Restore usunie aktualne pliki WordPress"
    echo "i nadpisze bazę danych."
    echo

    read -r -p "Kontynuować? [y/N]: " ANSWER

    case "$ANSWER" in
        y|Y|yes|YES|tak|TAK)
            ;;
        *)
            log "Restore anulowany."
            exit 0
            ;;
    esac
fi

log "Stopping WordPress..."
docker stop comzezarl-wp >/dev/null

log "Cleaning WordPress volume..."

docker run --rm \
    -v "$WP_VOLUME":/data \
    alpine \
    sh -c 'find /data -mindepth 1 -maxdepth 1 -exec rm -rf {} +'

log "Restoring WordPress files..."

docker run --rm \
    -v "$WP_VOLUME":/data \
    -v "$(pwd)/$BACKUP_DIR":/backup:ro \
    alpine \
    sh -c 'cd /data && tar xzf /backup/backup-wp-files.tar.gz'

log "Recreating database..."

docker exec comzezarl-db mariadb \
    -uroot \
    -p"$MYSQL_ROOT_PASSWORD" \
    -e "
DROP DATABASE IF EXISTS \`$MYSQL_DATABASE\`;

CREATE DATABASE \`$MYSQL_DATABASE\`
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES
ON \`$MYSQL_DATABASE\`.*
TO '$MYSQL_USER'@'%';

FLUSH PRIVILEGES;
"

log "Importing database..."

docker exec -i comzezarl-db mariadb \
    -h 127.0.0.1 \
    -u"$MYSQL_USER" \
    -p"$MYSQL_PASSWORD" \
    "$MYSQL_DATABASE" \
    < "$BACKUP_DIR/backup-db.sql"

log "Reading current URL..."

OLD_URL=$(
docker exec comzezarl-db mariadb \
    -h 127.0.0.1 \
    -N \
    -B \
    -u"$MYSQL_USER" \
    -p"$MYSQL_PASSWORD" \
    "$MYSQL_DATABASE" \
    -e "
SELECT option_value
FROM \`${OPTIONS_TABLE}\`
WHERE option_name='home';
"
)

if [ -z "$OLD_URL" ]; then
    log_error "Nie udało się odczytać aktualnego URL z bazy danych."
    exit 1
fi

log "Old URL: $OLD_URL"
log "New URL: $WP_SITE_URL"

log "Updating WordPress URL..."

docker compose run --rm wpcli search-replace \
    "$OLD_URL" \
    "$WP_SITE_URL" \
    --all-tables \
    --skip-columns=guid

log "Starting WordPress..."

docker start comzezarl-wp >/dev/null

sleep 5

CURRENT_URL=$(docker compose run --rm wpcli option get home)

log "Current URL: $CURRENT_URL"

if [ "$CURRENT_URL" != "$WP_SITE_URL" ]; then
    log_error "Weryfikacja nie powiodła się. Oczekiwano: $WP_SITE_URL, otrzymano: $CURRENT_URL"
    exit 1
fi

log "========================================="
log "Restore completed successfully."
log "========================================="

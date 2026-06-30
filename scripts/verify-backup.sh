#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "Usage: ./scripts/verify-backup.sh backups/YYYY-MM-DD-HHMM"
  exit 1
fi

BACKUP_DIR="$1"
MANIFEST="$BACKUP_DIR/manifest.json"

if [ ! -f "$MANIFEST" ]; then
  echo "Missing manifest.json in: $BACKUP_DIR"
  exit 1
fi

DB_FILE="$BACKUP_DIR/backup-db.sql"
WP_FILE="$BACKUP_DIR/backup-wp-files.tar.gz"

if [ ! -f "$DB_FILE" ]; then
  echo "Missing file: $DB_FILE"
  exit 1
fi

if [ ! -f "$WP_FILE" ]; then
  echo "Missing file: $WP_FILE"
  exit 1
fi

EXPECTED_DB_SHA=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['files']['database']['sha256'])")
EXPECTED_WP_SHA=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['files']['wordpress']['sha256'])")

ACTUAL_DB_SHA=$(sha256sum "$DB_FILE" | awk '{print $1}')
ACTUAL_WP_SHA=$(sha256sum "$WP_FILE" | awk '{print $1}')

echo "Verifying backup: $BACKUP_DIR"
echo

FAILED=0

if [ "$EXPECTED_DB_SHA" = "$ACTUAL_DB_SHA" ]; then
  echo "Database: OK"
else
  echo "Database: FAILED"
  FAILED=1
fi

if [ "$EXPECTED_WP_SHA" = "$ACTUAL_WP_SHA" ]; then
  echo "WordPress files: OK"
else
  echo "WordPress files: FAILED"
  FAILED=1
fi

echo

if [ "$FAILED" -eq 0 ]; then
  echo "Backup verification PASSED"
  exit 0
else
  echo "Backup verification FAILED"
  exit 1
fi
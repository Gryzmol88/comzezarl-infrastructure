#!/bin/bash

set -e

LOG_FILE="logs/verify.log"
source scripts/common.sh

if [ -z "$1" ]; then
  log "Usage: ./scripts/verify-backup.sh backups/YYYY-MM-DD-HHMM"
  exit 1
fi

BACKUP_DIR="$1"
MANIFEST="$BACKUP_DIR/manifest.json"

if [ ! -f "$MANIFEST" ]; then
  log_error "Missing manifest.json in: $BACKUP_DIR"
  exit 1
fi

if ! python3 -m json.tool "$MANIFEST" >/dev/null 2>&1; then
  log_error "Invalid manifest.json format: $MANIFEST"
  exit 1
fi

DB_FILE="$BACKUP_DIR/backup-db.sql"
WP_FILE="$BACKUP_DIR/backup-wp-files.tar.gz"

if [ ! -f "$DB_FILE" ]; then
  log_error "Missing file: $DB_FILE"
  exit 1
fi

if [ ! -f "$WP_FILE" ]; then
  log_error "Missing file: $WP_FILE"
  exit 1
fi

EXPECTED_DB_SHA=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['files']['database']['sha256'])")
EXPECTED_WP_SHA=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['files']['wordpress']['sha256'])")

ACTUAL_DB_SHA=$(sha256sum "$DB_FILE" | awk '{print $1}')
ACTUAL_WP_SHA=$(sha256sum "$WP_FILE" | awk '{print $1}')

log "Verifying backup: $BACKUP_DIR"


FAILED=0

if [ "$EXPECTED_DB_SHA" = "$ACTUAL_DB_SHA" ]; then
  log "Database: OK"
else
  log_error "Database: FAILED"
  FAILED=1
fi

if [ "$EXPECTED_WP_SHA" = "$ACTUAL_WP_SHA" ]; then
  log "WordPress files: OK"
else
  log_error "WordPress files: FAILED"
  FAILED=1
fi


if [ "$FAILED" -eq 0 ]; then
  log "Backup verification PASSED"

  python3 - "$MANIFEST" <<'PY'
import json
import sys
from datetime import datetime, timezone

manifest_path = sys.argv[1]

with open(manifest_path, "r", encoding="utf-8") as f:
    data = json.load(f)

data.setdefault("status", {})
data["status"]["verified"] = True

data["verification"] = {
    "result": "passed",
    "verified_at": datetime.now(timezone.utc).astimezone().isoformat()
}

with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY

  exit 0
else
  log_error "Backup verification FAILED"

  python3 - "$MANIFEST" <<'PY'
import json
import sys
from datetime import datetime, timezone

manifest_path = sys.argv[1]

with open(manifest_path, "r", encoding="utf-8") as f:
    data = json.load(f)

data.setdefault("status", {})
data["status"]["verified"] = False

data["verification"] = {
    "result": "failed",
    "verified_at": datetime.now(timezone.utc).astimezone().isoformat()
}

with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY

  exit 1
fi
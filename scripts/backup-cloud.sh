#!/bin/bash

set -e

LOG_FILE="logs/cloud.log"
source scripts/common.sh
load_env

BACKUP_REMOTE_ENABLED=${BACKUP_REMOTE_ENABLED:-false}
BACKUP_REMOTE_NAME=${BACKUP_REMOTE_NAME:-gdrive}
BACKUP_REMOTE_PATH=${BACKUP_REMOTE_PATH:-Comzezarl/backups}
BACKUP_REMOTE_CLEANUP=${BACKUP_REMOTE_CLEANUP:-false}
BACKUP_REMOTE_RETENTION_DAYS=${BACKUP_REMOTE_RETENTION_DAYS:-365}
BACKUP_REMOTE_PROVIDER=${BACKUP_REMOTE_PROVIDER:-Google Drive}

if [ -z "$1" ]; then
  log_error "Usage: ./scripts/backup-cloud.sh backups/YYYY-MM-DD-HHMM"
  exit 1
fi

BACKUP_DIR="$1"
BACKUP_ID=$(basename "$BACKUP_DIR")
MANIFEST="$BACKUP_DIR/manifest.json"
REMOTE_TARGET="$BACKUP_REMOTE_NAME:$BACKUP_REMOTE_PATH/$BACKUP_ID"

if [ "$BACKUP_REMOTE_ENABLED" != "true" ]; then
  log_warn "Remote backup is disabled."
  exit 0
fi

require_command rclone
require_directory "$BACKUP_DIR"
require_file "$MANIFEST"

log "Uploading backup to remote storage..."
log "Backup directory: $BACKUP_DIR"
log "Remote target: $REMOTE_TARGET"

rclone copy "$BACKUP_DIR" "$REMOTE_TARGET" \
  --retries 5 \
  --low-level-retries 10 \
  --drive-pacer-min-sleep 2s \
  --drive-pacer-burst 100

log "Verifying remote upload..."

REMOTE_FILE_COUNT=$(rclone lsf "$REMOTE_TARGET" | wc -l)

if [ "$REMOTE_FILE_COUNT" -lt 3 ]; then
  log_error "Remote upload verification failed. Expected at least 3 files, found: $REMOTE_FILE_COUNT"
  exit 1
fi

log "Remote upload verified."
log "Updating manifest cloud status..."

python3 - "$MANIFEST" "$REMOTE_TARGET" "$BACKUP_REMOTE_PROVIDER" <<'PY'
import json
import sys
from datetime import datetime, timezone

manifest_path = sys.argv[1]
remote_target = sys.argv[2]
provider = sys.argv[3]

with open(manifest_path, "r", encoding="utf-8") as f:
    data = json.load(f)

data["cloud"] = {
    "enabled": True,
    "provider": provider,
    "uploaded": True,
    "uploaded_at": datetime.now(timezone.utc).astimezone().isoformat(),
    "remote": remote_target
}

with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY

log "Uploading updated manifest..."

rclone copy "$MANIFEST" "$REMOTE_TARGET" \
  --retries 10 \
  --low-level-retries 20 \
  --drive-pacer-min-sleep 2s \
  --drive-pacer-burst 50

if [ "$BACKUP_REMOTE_CLEANUP" = "true" ]; then
  log "Removing remote backups older than ${BACKUP_REMOTE_RETENTION_DAYS} days..."

  rclone delete "$BACKUP_REMOTE_NAME:$BACKUP_REMOTE_PATH" \
    --min-age "${BACKUP_REMOTE_RETENTION_DAYS}d"

  rclone rmdirs "$BACKUP_REMOTE_NAME:$BACKUP_REMOTE_PATH"

  log "Remote cleanup completed."
else
  log "Remote cleanup skipped."
fi

log "Cloud backup completed."
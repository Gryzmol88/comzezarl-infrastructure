#!/bin/bash
set -euo pipefail

# Konfiguracja
source scripts/common.sh
load_env

REMOTE_NAME="${BACKUP_REMOTE_NAME:-gdrive}"
REMOTE_PATH="${BACKUP_REMOTE_PATH:-Comzezarl/backups}"
REMOTE="${REMOTE_NAME}:${REMOTE_PATH}"

MODE="${1:---dry-run}"
MAX_DELETE=3

# Backupy chronione przed automatycznym usunięciem
PROTECTED=(
    "2026-10-30-1922"
)

if [[ "$MODE" != "--dry-run" && "$MODE" != "--delete" ]]; then
    echo "Użycie: $0 [--dry-run|--delete]"
    exit 1
fi

# Pobierz listę katalogów dwukrotnie i porównaj wyniki
echo "Sprawdzanie listy backupów na Google Drive..."

BACKUPS_FIRST=$(rclone lsf "$REMOTE" --dirs-only | sed 's:/$::' | sort -r)

sleep 3

BACKUPS_SECOND=$(rclone lsf "$REMOTE" --dirs-only | sed 's:/$::' | sort -r)

if [[ "$BACKUPS_FIRST" != "$BACKUPS_SECOND" ]]; then
    echo "BŁĄD: Listy backupów z Google Drive są różne."
    echo "Rotacja została przerwana."
    exit 1
fi

BACKUPS="$BACKUPS_SECOND"

echo "Listy backupów są zgodne."

if [[ -z "$BACKUPS" ]]; then
    echo "BŁĄD: Nie znaleziono backupów."
    exit 1
fi

# Sprawdzenie integralności najnowszego backupu
LATEST_BACKUP=$(printf '%s\n' "$BACKUPS" | head -n 1)
LATEST_REMOTE="$REMOTE/$LATEST_BACKUP"

echo "Weryfikacja najnowszego backupu: $LATEST_BACKUP"

# Pobierz manifest
MANIFEST_JSON=$(rclone cat "$LATEST_REMOTE/manifest.json")

# Odczytaj oczekiwane sumy SHA-256
DB_HASH=$(printf '%s' "$MANIFEST_JSON" | python3 -c \
    'import json,sys; print(json.load(sys.stdin)["files"]["database"]["sha256"])')

WP_HASH=$(printf '%s' "$MANIFEST_JSON" | python3 -c \
    'import json,sys; print(json.load(sys.stdin)["files"]["wordpress"]["sha256"])')

# Porównaj sumy z rzeczywistą zawartością plików w chmurze
echo "Sprawdzanie bazy danych..."
DB_ACTUAL=$(rclone cat "$LATEST_REMOTE/backup-db.sql" | sha256sum | cut -d' ' -f1)

if [[ "$DB_ACTUAL" != "$DB_HASH" ]]; then
    echo "BŁĄD: Niezgodna suma SHA-256 bazy danych."
    exit 1
fi

echo "Baza danych: OK"

echo "Sprawdzanie plików WordPressa..."
WP_ACTUAL=$(rclone cat "$LATEST_REMOTE/backup-wp-files.tar.gz" | sha256sum | cut -d' ' -f1)

if [[ "$WP_ACTUAL" != "$WP_HASH" ]]; then
    echo "BŁĄD: Niezgodna suma SHA-256 plików WordPressa."
    exit 1
fi

echo "Pliki WordPressa: OK"
echo "Integralność najnowszego backupu potwierdzona."

# Sprawdź poprawność nazw katalogów i dat
while IFS= read -r backup; do
    if [[ ! "$backup" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]]; then
        echo "BŁĄD: Nieznany katalog: $backup"
        exit 1
    fi

    backup_date="${backup:0:10}"

    if [[ "$(date -d "$backup_date" +%F 2>/dev/null)" != "$backup_date" ]]; then
        echo "BŁĄD: Niepoprawna data: $backup"
        exit 1
    fi
done <<< "$BACKUPS"

declare -A KEEP
declare -A DAYS
declare -A WEEKS
declare -A MONTHS

# 1. Zachowaj backupy chronione, jeśli istnieją
for backup in "${PROTECTED[@]}"; do
    if grep -Fxq "$backup" <<< "$BACKUPS"; then
        KEEP["$backup"]=1
    fi
done

# 2. Zachowaj kopie z 4 ostatnich różnych dni
daily=0

while IFS= read -r backup; do
    day="${backup:0:10}"

    if [[ -z "${DAYS[$day]:-}" && "$daily" -lt 4 ]]; then
        KEEP["$backup"]=1
        DAYS["$day"]=1
        ((daily+=1))
    fi
done <<< "$BACKUPS"

# 3. Zachowaj kopie z 4 różnych tygodni
weekly=0

while IFS= read -r backup; do
    day="${backup:0:10}"
    week=$(date -d "$day" +%G-%V)

    if [[ -z "${WEEKS[$week]:-}" && "$weekly" -lt 4 ]]; then
        KEEP["$backup"]=1
        WEEKS["$week"]=1
        ((weekly+=1))
    fi
done <<< "$BACKUPS"

# 4. Zachowaj kopie z 3 różnych miesięcy
monthly=0

while IFS= read -r backup; do
    month="${backup:0:7}"

    if [[ -z "${MONTHS[$month]:-}" && "$monthly" -lt 3 ]]; then
        KEEP["$backup"]=1
        MONTHS["$month"]=1
        ((monthly+=1))
    fi
done <<< "$BACKUPS"

echo "================================"
echo "Rotacja backupów Google Drive"
echo "Tryb: $MODE"
echo "Limit usuwania: $MAX_DELETE"
echo "================================"

keep_count=0
delete_count=0

while IFS= read -r backup; do
    if [[ -n "${KEEP[$backup]:-}" ]]; then
        echo "[ZACHOWAJ] $backup"
        ((keep_count+=1))
    else
        if [[ "$MODE" == "--delete" && "$delete_count" -ge "$MAX_DELETE" ]]; then
            echo "[POMIŃ - LIMIT] $backup"
            continue
        fi

        echo "[DO USUNIĘCIA] $backup"

        if [[ "$MODE" == "--delete" ]]; then
            rclone purge "$REMOTE/$backup"
        fi

        ((delete_count+=1))
    fi
done <<< "$BACKUPS"

echo "================================"
echo "Zachowane: $keep_count"
echo "Do usunięcia w tym uruchomieniu: $delete_count"
echo "Gotowe."

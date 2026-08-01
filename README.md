# Comzezarl Infrastructure

Kompletna infrastruktura Docker dla strony **comzezarl.pl** oparta o Docker Compose, Nginx, WordPress, MariaDB oraz własne skrypty backup/restore.

## Architektura

```text
Internet
    |
    v
Nginx
    |
    v
WordPress
    |
    v
MariaDB

backup.sh
    |
    v
backups/YYYY-MM-DD-HHMM/
├── backup-db.sql
└── backup-wp-files.tar.gz
```

## Funkcje

- Docker Compose
- WordPress
- MariaDB
- Nginx Reverse Proxy
- WP-CLI
- Gzip
- Cache plików statycznych
- Security Headers
- Rate Limiting
- Backup i Restore
- Automatyczna zmiana URL podczas restore

## Struktura

```text
.
├── docker-compose.yaml
├── .env.example
├── nginx/
├── php/
├── scripts/
│   ├── common.sh
│   ├── backup.sh
│   └── restore.sh
├── backups/
└── README.md
```

## Uruchomienie

```bash
docker compose up -d
docker compose ps
docker compose logs -f
```

## Backup

```bash
./scripts/backup.sh
```

## Restore

```bash
docker compose up -d
./scripts/restore.sh backups/YYYY-MM-DD-HHMM
```

Restore:
1. Sprawdza backup.
2. Czyści wolumen WordPress.
3. Odtwarza pliki.
4. Odtwarza bazę.
5. Zmienia URL przez WP-CLI.
6. Uruchamia WordPress.
7. Weryfikuje adres.

## Migracja

```text
Hosting
   |
.wpress
   |
Lokalny Docker
   |
backup.sh
   |
backup-db.sql + backup-wp-files.tar.gz
   |
Raspberry Pi
   |
restore.sh
```

Po migracji projekt korzysta wyłącznie z własnych backupów.

## Roadmap

### Gotowe

- Docker Compose
- WordPress
- MariaDB
- Nginx
- Backup
- Restore
- WP-CLI
- Migracja z produkcji
- Raspberry Pi

### Plan

- HTTPS (Let's Encrypt)
- Cloudflare
- Automatyczne odnowienie certyfikatów
- Backup do Google Drive
- Monitoring

## Git

```bash
git add .
git commit -m "Opis zmian"
git push
```

## Nie commitujemy

```text
.env
backups/
*.sql
*.tar.gz
logs/
```

# Comzezarl Infrastructure

WordPress + MariaDB running in Docker .

## Start

docker compose up -d

## Stop

docker compose down

# Backup Database

## Create database backup

Load environment variables and create a SQL dump:

```bash
source .env
docker exec comzezarl-db mariadb-dump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" > backup-db.sql
```

## Create dated backup

```bash
source .env
docker exec comzezarl-db mariadb-dump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" > backup-db-$(date +%Y-%m-%d).sql
```

Example output:

```text
backup-db-2026-06-23.sql
```

## Verify backup

Check file size:

```bash
ls -lh backup-db.sql
```

Preview the beginning of the dump:

```bash
head backup-db.sql
```

Expected output:

```text
-- MariaDB dump
-- Host: localhost
-- Database: comzezarl_wp
```

## Restore database backup

```bash
source .env
cat backup-db.sql | docker exec -i comzezarl-db mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"
```

## Notes

The database backup contains:

* WordPress posts
* Pages
* Users
* Settings
* Plugin configuration

The database backup does **not** contain:

* Uploaded images
* Themes
* Plugin files

A complete WordPress backup requires both the database dump and a backup of the WordPress files.



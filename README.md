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
# WordPress Files Backup

## Create WordPress files backup

List Docker volumes:

```bash
docker volume ls
```

Find the WordPress volume (for example):

```text
comzezarl-local_comzezarl_wp_data
```

Create backup:

```bash
docker run --rm \
-v comzezarl-local_comzezarl_wp_data:/data \
-v $(pwd):/backup \
alpine \
tar czf /backup/backup-wp-files.tar.gz /data
```

This creates:

```text
backup-wp-files.tar.gz
```

## Verify backup

Check file size:

```bash
ls -lh backup-wp-files.tar.gz
```

Preview archive contents:

```bash
tar -tzf backup-wp-files.tar.gz | head
```

Expected output:

```text
data/
data/wp-content/
data/wp-admin/
data/wp-includes/
```

## Restore WordPress files

Start a fresh WordPress environment:

```bash
docker compose up -d
```

Check the WordPress volume name:

```bash
docker volume ls
```

Restore files:

```bash
docker run --rm \
-v comzezarl-local_comzezarl_wp_data:/data \
-v $(pwd):/backup \
alpine \
tar xzf /backup/backup-wp-files.tar.gz -C /
```

## Full WordPress Recovery

A complete WordPress recovery requires:

```text
backup-db.sql
backup-wp-files.tar.gz
```

Restore order:

1. Start Docker containers
2. Restore WordPress files
3. Restore database

Restore database:

```bash
source .env

cat backup-db.sql | docker exec -i comzezarl-db mariadb \
-u"$MYSQL_USER" \
-p"$MYSQL_PASSWORD" \
"$MYSQL_DATABASE"
```

After restoration, the site should contain:

* Posts
* Pages
* Users
* Images
* Themes
* Plugins
* WordPress settings

```
```




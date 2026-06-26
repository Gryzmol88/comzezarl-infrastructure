# Comzezarl Infrastructure

Infrastruktura dla strony **comzezarl.com** oparta o:

* Docker
* WordPress
* MariaDB

Projekt jest przygotowany do uruchomienia lokalnie oraz do późniejszej migracji na Raspberry Pi.

---

# Struktura projektu

```text
comzezarl-local/
├── backups/
├── .env
├── .env.example
├── .gitignore
├── backup.sh
├── docker-compose.yaml
└── README.md
```

## Opis plików

| Plik                | Opis                               |
| ------------------- | ---------------------------------- |
| docker-compose.yaml | Definicja kontenerów Docker        |
| .env                | Konfiguracja lokalna i hasła       |
| .env.example        | Przykładowa konfiguracja bez haseł |
| backup.sh           | Automatyczne wykonywanie backupów  |
| backups/            | Katalog przechowujący backupy      |
| README.md           | Dokumentacja projektu              |

---

# Uruchomienie projektu

## Start kontenerów

```bash
docker compose up -d
```

### Co robi ta komenda?

```text
docker      -> uruchamia Dockera
compose     -> używa konfiguracji z docker-compose.yaml
up          -> tworzy i uruchamia kontenery
-d          -> uruchamia w tle (detached)
```

---

## Sprawdzenie działających kontenerów

```bash
docker ps
```

### Co robi ta komenda?

Wyświetla wszystkie aktualnie uruchomione kontenery.

---

## Logi aplikacji

```bash
docker compose logs -f
```

### Co robi ta komenda?

```text
logs -> pokazuje logi kontenerów
-f   -> śledzi logi na żywo
```

---

## Zatrzymanie projektu

```bash
docker compose down
```

### Co robi ta komenda?

```text
Zatrzymuje kontenery.
Usuwa kontenery.
Pozostawia dane w wolumenach.
```

---

# Konfiguracja środowiska

Plik:

```text
.env
```

Przykład:

```env
MYSQL_DATABASE=comzezarl_wp
MYSQL_USER=comzezarl_user
MYSQL_PASSWORD=CHANGE_ME
MYSQL_ROOT_PASSWORD=CHANGE_ME

WORDPRESS_TABLE_PREFIX=cz_
WORDPRESS_PORT=8080
```

## Opis zmiennych

### MYSQL_DATABASE

Nazwa bazy danych WordPress.

### MYSQL_USER

Użytkownik wykorzystywany przez WordPress.

### MYSQL_PASSWORD

Hasło użytkownika WordPress.

### MYSQL_ROOT_PASSWORD

Hasło administratora MariaDB.

### WORDPRESS_TABLE_PREFIX

Prefiks tabel WordPress.

Przykład:

```text
cz_posts
cz_users
cz_options
```

### WORDPRESS_PORT

Port wystawiony lokalnie.

Przykład:

```text
http://localhost:8080
```

---

# Backup bazy danych

## Utworzenie backupu

```bash
source .env

docker exec comzezarl-db mariadb-dump \
-u"$MYSQL_USER" \
-p"$MYSQL_PASSWORD" \
"$MYSQL_DATABASE" \
> backup-db.sql
```

### Co robi ta komenda?

```text
source .env                -> wczytuje zmienne środowiskowe
docker exec                -> wykonuje polecenie w kontenerze
comzezarl-db               -> kontener MariaDB
mariadb-dump               -> eksport bazy danych
> backup-db.sql            -> zapis do pliku
```

---

# Backup plików WordPress

## Utworzenie backupu

```bash
docker run --rm \
-v comzezarl-local_comzezarl_wp_data:/data \
-v $(pwd):/backup \
alpine \
tar czf /backup/backup-wp-files.tar.gz /data
```

### Co robi ta komenda?

```text
docker run      -> uruchamia tymczasowy kontener
--rm            -> usuwa kontener po zakończeniu
-v              -> montuje wolumeny
alpine          -> lekki system Linux
tar czf         -> tworzy archiwum .tar.gz
```

---

# Automatyczny backup

Uruchomienie:

```bash
./backup.sh
```

Skrypt:

1. Tworzy katalog z aktualną datą.
2. Wykonuje backup bazy danych.
3. Wykonuje backup plików WordPress.
4. Zapisuje backup w katalogu:

```text
backups/YYYY-MM-DD-HHMM/
```

Przykład:

```text
backups/2026-06-23-2054/
├── backup-db.sql
└── backup-wp-files.tar.gz
```

---

# Odtwarzanie po awarii

## 1. Uruchom środowisko

```bash
docker compose up -d
```

## 2. Przywróć pliki WordPress

```bash
docker run --rm \
-v comzezarl-local_comzezarl_wp_data:/data \
-v $(pwd):/backup \
alpine \
tar xzf /backup/backup-wp-files.tar.gz -C /
```

## 3. Przywróć bazę danych

```bash
source .env

cat backup-db.sql | docker exec -i comzezarl-db mariadb \
-u"$MYSQL_USER" \
-p"$MYSQL_PASSWORD" \
"$MYSQL_DATABASE"
```

---

# Git

## Dodanie zmian

```bash
git add .
```

## Commit

```bash
git commit -m "Opis zmian"
```

## Wysłanie na GitHub

```bash
git push
```

---

# Ważne

Nigdy nie wysyłaj do GitHub:

```text
.env
backups/
*.sql
*.tar.gz
```

Pliki te są ignorowane przez `.gitignore`.


# Automatyczne przywracanie (Restore)

Skrypt `restore.sh` automatyzuje proces odtworzenia całej strony WordPress z wcześniej wykonanego backupu.

## Wymagania

Przed uruchomieniem skryptu:

* uruchom kontenery Docker,
* upewnij się, że istnieje katalog z backupem.

Przykład:

```text
backups/
└── 2026-06-26-1030/
    ├── backup-db.sql
    └── backup-wp-files.tar.gz
```

---

## Uruchomienie kontenerów

```bash
docker compose up -d
```

### Co robi ta komenda?

```text
docker compose -> uruchamia projekt z docker-compose.yaml
up             -> tworzy i uruchamia kontenery
-d             -> uruchamia je w tle
```

---

## Uruchomienie restore

```bash
./restore.sh backups/2026-06-26-1030
```

### Co oznacza ta komenda?

```text
./restore.sh               -> uruchamia skrypt restore
backups/...                -> wskazuje katalog z backupem
```

---

## Co wykonuje skrypt?

### 1. Sprawdza poprawność backupu

Weryfikuje, czy istnieją pliki:

```text
backup-db.sql
backup-wp-files.tar.gz
```

Jeżeli któregoś brakuje, skrypt kończy działanie.

---

### 2. Wczytuje konfigurację

```bash
source .env
```

Ładuje zmienne środowiskowe:

```text
MYSQL_DATABASE
MYSQL_USER
MYSQL_PASSWORD
```

Dzięki temu nie trzeba wpisywać haseł ręcznie.

---

### 3. Przywraca pliki WordPress

Uruchamiany jest tymczasowy kontener Alpine:

```text
Docker Volume
        ▲
        │
backup-wp-files.tar.gz
```

Skrypt rozpakowuje:

```text
backup-wp-files.tar.gz
```

do wolumenu WordPress.

---

### 4. Przywraca bazę danych

Importowany jest plik:

```text
backup-db.sql
```

do kontenera MariaDB.

Wszystkie tabele WordPress zostają odtworzone.

---

### 5. Restartuje kontenery

```bash
docker compose restart
```

Dzięki temu WordPress ponownie wczytuje:

* pliki,
* konfigurację,
* bazę danych.

---

## Test poprawności

Po zakończeniu przywracania otwórz:

```text
http://localhost:8080
```

Sprawdź:

* logowanie administratora,
* wpisy,
* zdjęcia,
* menu,
* podstrony,
* motyw,
* wtyczki.

Jeżeli wszystko działa poprawnie, oznacza to, że backup został prawidłowo odtworzony.

---

## Typowy scenariusz awarii

```bash
docker compose down -v
docker compose up -d
./restore.sh backups/2026-06-26-1030
```

Po wykonaniu powyższych poleceń środowisko powinno zostać odtworzone do stanu z chwili wykonania backupu.


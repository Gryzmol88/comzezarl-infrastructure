#!/bin/bash

# =====================================
# Common helpers
# =====================================

LOG_DIR="${LOG_DIR:-logs}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/app.log}"

mkdir -p "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" | tee -a "$LOG_FILE"
}

log_warn() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" | tee -a "$LOG_FILE"
}

log_error() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" | tee -a "$LOG_FILE" >&2
}

print_separator() {
  log "========================================="
}

require_file() {
  if [ ! -f "$1" ]; then
    log_error "Required file not found: $1"
    exit 1
  fi
}

require_directory() {
  if [ ! -d "$1" ]; then
    log_error "Required directory not found: $1"
    exit 1
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "Required command not found: $1"
    exit 1
  fi
}

require_env() {
  if [ -z "${!1}" ]; then
    log_error "Environment variable not set: $1"
    exit 1
  fi
}

load_env() {
  if [ ! -f ".env" ]; then
    log_error ".env file not found"
    exit 1
  fi

  source .env

  require_env MYSQL_DATABASE
  require_env MYSQL_USER
  require_env MYSQL_PASSWORD
}
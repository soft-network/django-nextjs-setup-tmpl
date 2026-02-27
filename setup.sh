#!/usr/bin/env bash
# ============================================================
# setup.sh — Intelligentes Projekt-Setup-Tool (v2)
# Erkennt was installiert ist, installiert was fehlt,
# und bereitet die komplette Entwicklungsumgebung vor.
#
# Usage:
#   ./setup.sh              # Normaler Lauf
#   ./setup.sh --dry-run    # Zeigt nur was passieren würde
#   ./setup.sh --check      # Prüft nur den Status
#   ./setup.sh --clean      # Entfernt generierte Projektdateien
# ============================================================
set -euo pipefail

# === Farben & Logging ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${BLUE}[SETUP]${NC} $1"; }
success() { echo -e "${GREEN}[  OK ]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[FAIL]${NC} $1" >&2; }
info()    { echo -e "${CYAN}[INFO]${NC} $1"; }

# === CLI Flags ===
DRY_RUN=false
CHECK_ONLY=false
CLEAN=false

for arg in "$@"; do
    case "$arg" in
        --dry-run)    DRY_RUN=true ;;
        --check)      CHECK_ONLY=true ;;
        --clean)      CLEAN=true ;;
        -h|--help)
            echo "Usage: ./setup.sh [--dry-run] [--check] [--clean] [-h|--help]"
            exit 0
            ;;
        *) error "Unbekanntes Argument: $arg"; exit 1 ;;
    esac
done

# === Config laden ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/project.conf"

if [ ! -f "$CONF_FILE" ]; then
    error "project.conf nicht gefunden in: $SCRIPT_DIR"
    exit 1
fi

source "$CONF_FILE"

# === OS-Erkennung ===
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt &>/dev/null; then echo "debian"
        elif command -v dnf &>/dev/null; then echo "fedora"
        elif command -v pacman &>/dev/null; then echo "arch"
        else echo "linux-unknown"; fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then echo "macos"
    else echo "unknown"; fi
}

OS_TYPE=$(detect_os)
log "Betriebssystem: $OS_TYPE"

# === Hilfsfunktionen ===
cmd_exists() { command -v "$1" &>/dev/null; }

get_version() {
    local cmd="$1"
    if cmd_exists "$cmd"; then
        case "$cmd" in
            python3)    python3 --version 2>&1 | awk '{print $2}' ;;
            node)       node --version 2>&1 | sed 's/^v//' ;;
            uv)         uv --version 2>&1 | awk '{print $2}' ;;
            pnpm)       pnpm --version 2>&1 ;;
            npm)        npm --version 2>&1 ;;
            git)        git --version 2>&1 | awk '{print $3}' ;;
            docker)     docker --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1 ;;
            neonctl)    neonctl --version 2>&1 | head -1 ;;
            redis-cli)  redis-cli --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1 ;;
            just)       just --version 2>&1 | awk '{print $2}' ;;
            ruff)       ruff --version 2>&1 | awk '{print $2}' ;;
            *)          echo "unknown" ;;
        esac
    else
        echo "nicht installiert"
    fi
}

version_gte() {
    printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1 | grep -q "^$2$"
}

run_or_dry() {
    if $DRY_RUN; then
        info "[DRY-RUN] $*"
    else
        "$@"
    fi
}

pkg_install() {
    local pkg="$1"
    case "$OS_TYPE" in
        debian) run_or_dry sudo apt-get install -y "$pkg" ;;
        fedora) run_or_dry sudo dnf install -y "$pkg" ;;
        arch)   run_or_dry sudo pacman -S --noconfirm "$pkg" ;;
        macos)
            if ! cmd_exists brew; then
                error "Homebrew nicht gefunden: https://brew.sh"
                return 1
            fi
            run_or_dry brew install "$pkg"
            ;;
        *) error "Kann $pkg nicht installieren auf: $OS_TYPE"; return 1 ;;
    esac
}

# ============================================================
# STATUS-CHECK
# ============================================================
print_status() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║              📋 UMGEBUNGS-STATUS                     ║"
    echo "╠══════════════════════════════════════════════════════╣"
    echo "║  KERN-TOOLS                                          ║"
    echo "╠══════════════════════════════════════════════════════╣"

    local core_tools=("python3" "node" "git" "uv" "pnpm")
    for tool in "${core_tools[@]}"; do
        local ver=$(get_version "$tool")
        if cmd_exists "$tool"; then
            printf "║  %-14s ✅  %-34s ║\n" "$tool" "$ver"
        else
            printf "║  %-14s ❌  %-34s ║\n" "$tool" "nicht installiert"
        fi
    done

    echo "╠══════════════════════════════════════════════════════╣"
    echo "║  SERVICES & TOOLS                                    ║"
    echo "╠══════════════════════════════════════════════════════╣"

    local extra_tools=("docker" "neonctl" "redis-cli" "just" "ruff")
    for tool in "${extra_tools[@]}"; do
        local ver=$(get_version "$tool")
        if cmd_exists "$tool"; then
            printf "║  %-14s ✅  %-34s ║\n" "$tool" "$ver"
        else
            printf "║  %-14s ❌  %-34s ║\n" "$tool" "nicht installiert"
        fi
    done

    # Docker Compose separat prüfen
    if cmd_exists docker && docker compose version &>/dev/null; then
        local dc_ver=$(docker compose version --short 2>/dev/null || echo "?")
        printf "║  %-14s ✅  %-34s ║\n" "compose" "$dc_ver"
    else
        printf "║  %-14s ❌  %-34s ║\n" "compose" "nicht installiert"
    fi

    echo "╠══════════════════════════════════════════════════════╣"
    echo "║  PROJEKT-STRUKTUR                                    ║"
    echo "╠══════════════════════════════════════════════════════╣"

    local checks=(
        "Backend:$BACKEND_DIR/pyproject.toml"
        "Frontend:$FRONTEND_DIR/package.json"
        "Docker:docker-compose.yml"
        "CI/CD:.github/workflows/ci.yml"
        "Env:.env"
        "Justfile:justfile"
    )
    for check in "${checks[@]}"; do
        local label="${check%%:*}"
        local file="${check#*:}"
        if [ -f "$file" ]; then
            printf "║  %-14s ✅  %-34s ║\n" "$label" "konfiguriert"
        else
            printf "║  %-14s ❌  %-34s ║\n" "$label" "nicht eingerichtet"
        fi
    done

    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
}

# ============================================================
# PHASE 1: KERN-INSTALLATIONEN
# ============================================================

install_python() {
    if cmd_exists python3; then
        local current=$(get_version python3)
        if version_gte "$current" "$PYTHON_VER"; then
            success "Python $current"; return 0
        fi
    fi
    log "Installiere Python..."
    case "$OS_TYPE" in
        debian) run_or_dry sudo apt-get update -qq && pkg_install "python3" && pkg_install "python3-venv" ;;
        fedora) pkg_install "python3" ;;
        arch)   pkg_install "python" ;;
        macos)  pkg_install "python@${PYTHON_VER}" ;;
    esac
}

install_node() {
    if cmd_exists node; then
        local current=$(get_version node)
        local wanted="${NODE_VER}"; [ "$wanted" = "latest" ] && wanted="20"
        if version_gte "$current" "$wanted"; then
            success "Node.js v$current"; return 0
        fi
    fi
    log "Installiere Node.js..."
    case "$OS_TYPE" in
        debian|fedora)
            local node_major="${NODE_VER}"; [ "$node_major" = "latest" ] && node_major="22"
            run_or_dry bash -c "curl -fsSL https://deb.nodesource.com/setup_${node_major}.x | sudo -E bash -"
            pkg_install "nodejs"
            ;;
        arch)   pkg_install "nodejs" && pkg_install "npm" ;;
        macos)  pkg_install "node" ;;
    esac
}

install_uv() {
    if cmd_exists uv; then success "uv $(get_version uv)"; return 0; fi
    [ "$PYTHON_PKG_MANAGER" != "uv" ] && return 0
    log "Installiere uv..."
    run_or_dry bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh"
    export PATH="$HOME/.local/bin:$PATH"
}

install_node_pkg_manager() {
    local mgr="${NODE_PKG_MANAGER:-pnpm}"
    [ "$mgr" = "npm" ] && { success "npm $(get_version npm)"; return 0; }
    if cmd_exists "$mgr"; then success "$mgr $(get_version "$mgr")"; return 0; fi
    log "Installiere $mgr..."
    case "$mgr" in
        pnpm) run_or_dry npm install -g pnpm ;;
        yarn) run_or_dry npm install -g yarn ;;
    esac
}

# ============================================================
# PHASE 2: SERVICES (Docker, Neon, Redis)
# ============================================================

install_docker() {
    [ "${INSTALL_DOCKER:-false}" != "true" ] && return 0

    if cmd_exists docker; then
        success "Docker $(get_version docker)"
    else
        log "Installiere Docker..."
        case "$OS_TYPE" in
            debian)
                # Docker offizielle Methode
                run_or_dry bash -c '
                    sudo apt-get update -qq
                    sudo apt-get install -y ca-certificates curl
                    sudo install -m 0755 -d /etc/apt/keyrings
                    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
                    sudo chmod a+r /etc/apt/keyrings/docker.asc
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                    sudo apt-get update -qq
                    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                '
                # User zur Docker-Gruppe hinzufügen
                if ! groups "$USER" | grep -q docker; then
                    run_or_dry sudo usermod -aG docker "$USER"
                    warn "Docker-Gruppe hinzugefügt. Bitte einmal aus- und einloggen!"
                fi
                ;;
            fedora)
                run_or_dry bash -c '
                    sudo dnf install -y dnf-plugins-core
                    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                    sudo systemctl start docker && sudo systemctl enable docker
                '
                ;;
            macos)
                warn "Bitte Docker Desktop manuell installieren: https://docker.com/products/docker-desktop"
                ;;
            arch)
                pkg_install "docker" && pkg_install "docker-compose"
                run_or_dry sudo systemctl start docker
                run_or_dry sudo systemctl enable docker
                ;;
        esac
    fi

    # Docker Compose prüfen
    if [ "${INSTALL_DOCKER_COMPOSE:-false}" = "true" ]; then
        if cmd_exists docker && docker compose version &>/dev/null; then
            success "Docker Compose $(docker compose version --short 2>/dev/null)"
        else
            warn "Docker Compose nicht verfügbar — kommt mit Docker Desktop oder docker-compose-plugin"
        fi
    fi
}

install_neon_cli() {
    [ "${NEON_CLI:-false}" != "true" ] && return 0

    if cmd_exists neonctl; then
        success "Neon CLI $(get_version neonctl)"
        return 0
    fi

    log "Installiere Neon CLI..."
    if cmd_exists npm; then
        run_or_dry npm install -g neonctl
    else
        error "npm benötigt für Neon CLI Installation"
        return 1
    fi
}

install_redis() {
    [ "${INSTALL_REDIS:-false}" != "true" ] && return 0

    if [ "${REDIS_MODE:-docker}" = "docker" ]; then
        info "Redis wird via Docker bereitgestellt (siehe docker-compose.yml)"
        return 0
    fi

    if cmd_exists redis-cli; then
        success "Redis $(get_version redis-cli)"
        return 0
    fi

    log "Installiere Redis lokal..."
    case "$OS_TYPE" in
        debian) pkg_install "redis-server" ;;
        fedora) pkg_install "redis" ;;
        arch)   pkg_install "redis" ;;
        macos)  pkg_install "redis" ;;
    esac
}

install_just() {
    [ "${INSTALL_JUST:-false}" != "true" ] && return 0

    if cmd_exists just; then
        success "just $(get_version just)"
        return 0
    fi

    log "Installiere just..."
    case "$OS_TYPE" in
        debian)
            run_or_dry bash -c '
                curl -sSf https://just.systems/install.sh | sudo bash -s -- --to /usr/local/bin
            '
            ;;
        fedora) pkg_install "just" ;;
        arch)   pkg_install "just" ;;
        macos)  pkg_install "just" ;;
    esac
}

install_ruff() {
    [ "${INSTALL_RUFF:-false}" != "true" ] && return 0

    if cmd_exists ruff; then
        success "Ruff $(get_version ruff)"
        return 0
    fi

    log "Installiere Ruff..."
    if cmd_exists uv; then
        run_or_dry uv tool install ruff
    elif cmd_exists pip; then
        run_or_dry pip install ruff
    else
        warn "Weder uv noch pip gefunden für Ruff-Installation"
    fi
}

# ============================================================
# PHASE 3: PROJEKT-SETUP
# ============================================================

setup_backend() {
    log "━━━ Backend Setup ($BACKEND_DIR) ━━━"
    run_or_dry mkdir -p "$BACKEND_DIR"

    if [ -f "$BACKEND_DIR/pyproject.toml" ]; then
        success "Backend bereits initialisiert — überspringe"
        return 0
    fi

    $DRY_RUN && { info "[DRY-RUN] Backend mit Django $DJANGO_VER"; return 0; }

    cd "$BACKEND_DIR"

    case "$PYTHON_PKG_MANAGER" in
        uv)
            uv init --python "$PYTHON_VER" 2>/dev/null || true

            local django_spec="django"
            [ "${DJANGO_VER:-latest}" != "latest" ] && django_spec="django==${DJANGO_VER}.*"
            uv add "$django_spec"

            if [ -n "${PYTHON_EXTRAS:-}" ]; then
                log "Installiere Python-Extras..."
                for pkg in $PYTHON_EXTRAS; do
                    uv add "$pkg" 2>/dev/null && success "  + $pkg" || warn "  ⚠ $pkg fehlgeschlagen"
                done
            fi
            ;;
        pip)
            python3 -m venv .venv
            source .venv/bin/activate
            pip install --upgrade pip
            local django_spec="django"
            [ "${DJANGO_VER:-latest}" != "latest" ] && django_spec="django==${DJANGO_VER}.*"
            pip install "$django_spec"
            [ -n "${PYTHON_EXTRAS:-}" ] && pip install $PYTHON_EXTRAS
            pip freeze > requirements.txt
            ;;
    esac

    success "Backend bereit (Django ${DJANGO_VER:-latest})"
    cd ..
}

setup_frontend() {
    log "━━━ Frontend Setup ($FRONTEND_DIR) ━━━"

    if [ -f "$FRONTEND_DIR/package.json" ]; then
        success "Frontend bereits initialisiert — überspringe"
        return 0
    fi

    $DRY_RUN && { info "[DRY-RUN] Frontend mit Next.js $NEXTJS_VER"; return 0; }

    local npx_cmd="npx"
    [ "$NODE_PKG_MANAGER" = "pnpm" ] && npx_cmd="pnpm dlx"

    local nextjs_spec="create-next-app"
    [ "${NEXTJS_VER:-latest}" != "latest" ] && nextjs_spec="create-next-app@${NEXTJS_VER}"

    $npx_cmd $nextjs_spec "$FRONTEND_DIR" \
        --typescript --tailwind --eslint --app --src-dir \
        --import-alias "@/*" \
        --use-${NODE_PKG_MANAGER:-pnpm} \
        2>/dev/null || { error "Next.js Setup fehlgeschlagen"; return 1; }

    if [ -n "${NODE_EXTRAS:-}" ]; then
        cd "$FRONTEND_DIR"
        log "Installiere Node-Extras..."
        case "$NODE_PKG_MANAGER" in
            pnpm) pnpm add -D $NODE_EXTRAS 2>/dev/null ;;
            yarn) yarn add -D $NODE_EXTRAS 2>/dev/null ;;
            *)    npm install -D $NODE_EXTRAS 2>/dev/null ;;
        esac
        cd ..
    fi

    success "Frontend bereit (Next.js ${NEXTJS_VER:-latest})"
}

# ============================================================
# PHASE 4: DOCKER & COMPOSE
# ============================================================

generate_docker_compose() {
    [ "${GENERATE_DOCKERFILES:-false}" != "true" ] && return 0

    if [ -f "docker-compose.yml" ]; then
        success "docker-compose.yml existiert bereits"
        return 0
    fi

    log "Generiere docker-compose.yml..."
    $DRY_RUN && { info "[DRY-RUN] docker-compose.yml"; return 0; }

    cat > docker-compose.yml << YAML
# ============================================================
# Docker Compose — $PROJECT_NAME
# Usage: docker compose up -d
# ============================================================
name: ${PROJECT_NAME}

services:
YAML

    # Postgres Service
    if [[ "${DOCKER_SERVICES:-}" == *"postgres"* ]]; then
        cat >> docker-compose.yml << YAML
  db:
    image: postgres:${POSTGRES_VERSION:-16}-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: \${DB_USER:-${PROJECT_NAME}_user}
      POSTGRES_PASSWORD: \${DB_PASSWORD:-changeme}
      POSTGRES_DB: \${DB_NAME:-${PROJECT_NAME}_db}
    ports:
      - "\${DB_PORT:-5432}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${DB_USER:-${PROJECT_NAME}_user}"]
      interval: 5s
      timeout: 5s
      retries: 5

YAML
    fi

    # Redis Service
    if [[ "${DOCKER_SERVICES:-}" == *"redis"* ]]; then
        cat >> docker-compose.yml << YAML
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "\${REDIS_PORT:-6379}:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

YAML
    fi

    # MailHog Service
    if [[ "${DOCKER_SERVICES:-}" == *"mailhog"* ]]; then
        cat >> docker-compose.yml << YAML
  mailhog:
    image: mailhog/mailhog:latest
    restart: unless-stopped
    ports:
      - "1025:1025"   # SMTP
      - "8025:8025"   # Web UI

YAML
    fi

    # MinIO Service
    if [[ "${DOCKER_SERVICES:-}" == *"minio"* ]]; then
        cat >> docker-compose.yml << YAML
  minio:
    image: minio/minio:latest
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data

YAML
    fi

    # Volumes
    echo "volumes:" >> docker-compose.yml
    [[ "${DOCKER_SERVICES:-}" == *"postgres"* ]] && echo "  postgres_data:" >> docker-compose.yml
    [[ "${DOCKER_SERVICES:-}" == *"redis"* ]] && echo "  redis_data:" >> docker-compose.yml
    [[ "${DOCKER_SERVICES:-}" == *"minio"* ]] && echo "  minio_data:" >> docker-compose.yml

    success "docker-compose.yml erstellt"
}

generate_backend_dockerfile() {
    [ "${GENERATE_DOCKERFILES:-false}" != "true" ] && return 0

    if [ -f "$BACKEND_DIR/Dockerfile" ]; then
        success "Backend Dockerfile existiert bereits"
        return 0
    fi

    $DRY_RUN && { info "[DRY-RUN] Backend Dockerfile"; return 0; }

    cat > "$BACKEND_DIR/Dockerfile" << 'DOCKERFILE'
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Python deps
COPY pyproject.toml uv.lock* requirements*.txt* ./
RUN pip install --no-cache-dir uv && uv sync --frozen 2>/dev/null || pip install -r requirements.txt 2>/dev/null || true

# App code
COPY . .

EXPOSE 8000
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
DOCKERFILE

    success "Backend Dockerfile erstellt"
}

# ============================================================
# PHASE 5: CELERY CONFIG
# ============================================================

setup_celery() {
    [ "${SETUP_CELERY:-false}" != "true" ] && return 0

    if [ -f "$BACKEND_DIR/celery_app.py" ]; then
        success "Celery Config existiert bereits"
        return 0
    fi

    $DRY_RUN && { info "[DRY-RUN] Celery Config"; return 0; }

    cat > "$BACKEND_DIR/celery_app.py" << 'PYTHON'
"""
Celery Configuration
Importiere in deinem Django-Projekt __init__.py:
    from .celery_app import app as celery_app
    __all__ = ('celery_app',)
"""
import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

app = Celery('app')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()

# Beispiel-Task:
# @app.task(bind=True)
# def debug_task(self):
#     print(f'Request: {self.request!r}')
PYTHON

    success "Celery Config erstellt"
}

# ============================================================
# PHASE 6: CI/CD (GitHub Actions)
# ============================================================

setup_github_actions() {
    [ "${SETUP_GITHUB_ACTIONS:-false}" != "true" ] && return 0

    if [ -f ".github/workflows/ci.yml" ]; then
        success "GitHub Actions existiert bereits"
        return 0
    fi

    log "Generiere GitHub Actions Workflow..."
    $DRY_RUN && { info "[DRY-RUN] GitHub Actions"; return 0; }

    mkdir -p .github/workflows

    cat > .github/workflows/ci.yml << 'YAML'
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  PYTHON_VERSION: "3.12"
  NODE_VERSION: "22"

jobs:
  # ── Backend ────────────────────────────────────────
  backend:
    name: Backend Tests & Lint
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
          POSTGRES_DB: test_db
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Install uv
        uses: astral-sh/setup-uv@v4

      - name: Set up Python
        run: uv python install ${{ env.PYTHON_VERSION }}

      - name: Install dependencies
        run: uv sync

      - name: Run Ruff Linter
        run: uv run ruff check .

      - name: Run Ruff Formatter Check
        run: uv run ruff format --check .

      - name: Run Tests
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_db
          REDIS_URL: redis://localhost:6379/0
          DJANGO_SECRET_KEY: test-secret-key-not-for-production
        run: uv run python manage.py test

  # ── Frontend ───────────────────────────────────────
  frontend:
    name: Frontend Lint & Typecheck
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: frontend

    steps:
      - uses: actions/checkout@v4

      - name: Install pnpm
        uses: pnpm/action-setup@v4
        with:
          version: latest

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: pnpm
          cache-dependency-path: frontend/pnpm-lock.yaml

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Lint
        run: pnpm lint

      - name: Type Check
        run: pnpm tsc --noEmit

      - name: Build
        run: pnpm build
YAML

    success "GitHub Actions CI Pipeline erstellt"
}

# ============================================================
# PHASE 7: KONFIGURATIONSDATEIEN
# ============================================================

setup_env_file() {
    [ "${SETUP_ENV_FILE:-false}" != "true" ] && return 0
    [ -f ".env" ] && { success ".env existiert bereits"; return 0; }

    log "Erstelle .env Template..."
    $DRY_RUN && { info "[DRY-RUN] .env"; return 0; }

    local db_url="postgresql://user:password@localhost:5432/${PROJECT_NAME}_db"
    [ "${DB_ENGINE:-local}" = "neon" ] && db_url="postgresql://user:password@ep-xxxx.eu-central-1.aws.neon.tech/neondb?sslmode=require"

    cat > .env << EOF
# ============================================================
# Umgebungsvariablen — $PROJECT_NAME
# NICHT in Git committen!
# ============================================================

# Django
DJANGO_SECRET_KEY=change-me-$(openssl rand -hex 24 2>/dev/null || echo "generate-a-random-string-here")
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1

# Datenbank
DATABASE_URL=$db_url
DB_USER=${PROJECT_NAME}_user
DB_PASSWORD=changeme
DB_NAME=${PROJECT_NAME}_db

# Redis
REDIS_URL=redis://localhost:6379/0

# Celery
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/1

# Next.js
NEXT_PUBLIC_API_URL=http://localhost:8000/api

# Neon (falls DB_ENGINE=neon)
NEON_API_KEY=
NEON_PROJECT_ID=

# AI / Externe APIs
ANTHROPIC_API_KEY=
EOF

    # .env.example für Git (ohne echte Werte)
    sed 's/=.*/=/' .env > .env.example

    success ".env + .env.example erstellt"
}

setup_git() {
    [ "${SETUP_GIT:-false}" != "true" ] && return 0
    [ -d ".git" ] && { success "Git-Repo existiert bereits"; return 0; }

    log "Initialisiere Git..."
    $DRY_RUN && { info "[DRY-RUN] Git init"; return 0; }

    git init

    cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*.egg-info/
.venv/
*.egg

# Node
node_modules/
.next/
.turbo/

# Umgebung
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Build & Logs
dist/
build/
*.log

# Docker Volumes (lokal)
postgres_data/
redis_data/
EOF

    success ".gitignore erstellt"
}

setup_precommit() {
    [ "${SETUP_PRECOMMIT:-false}" != "true" ] && return 0
    [ -f ".pre-commit-config.yaml" ] && { success "Pre-commit existiert"; return 0; }

    $DRY_RUN && { info "[DRY-RUN] Pre-commit config"; return 0; }

    cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
EOF

    success "Pre-commit Config erstellt"
}

# ============================================================
# JUSTFILE
# ============================================================

generate_justfile() {
    [ "${SETUP_JUSTFILE:-false}" != "true" ] && return 0
    [ -f "justfile" ] && { success "justfile existiert bereits"; return 0; }

    $DRY_RUN && { info "[DRY-RUN] justfile"; return 0; }

    local py_run="uv run"
    [ "$PYTHON_PKG_MANAGER" = "pip" ] && py_run=".venv/bin/python"

    local nd_run="pnpm"
    [ "$NODE_PKG_MANAGER" = "npm" ] && nd_run="npm run"
    [ "$NODE_PKG_MANAGER" = "yarn" ] && nd_run="yarn"

    cat > justfile << EOF
# ============================================================
# justfile — $PROJECT_NAME
# Usage: just <command> | just --list
# ============================================================

default:
    @just --list

# ── Backend ─────────────────────────────────────────

backend:
    cd $BACKEND_DIR && $py_run manage.py runserver

migrate:
    cd $BACKEND_DIR && $py_run manage.py makemigrations
    cd $BACKEND_DIR && $py_run manage.py migrate

superuser:
    cd $BACKEND_DIR && $py_run manage.py createsuperuser

shell:
    cd $BACKEND_DIR && $py_run manage.py shell

test-backend:
    cd $BACKEND_DIR && $py_run manage.py test

lint-backend:
    cd $BACKEND_DIR && $py_run ruff check . --fix
    cd $BACKEND_DIR && $py_run ruff format .

# ── Frontend ────────────────────────────────────────

frontend:
    cd $FRONTEND_DIR && $nd_run dev

build-frontend:
    cd $FRONTEND_DIR && $nd_run build

lint-frontend:
    cd $FRONTEND_DIR && $nd_run lint

# ── Docker ──────────────────────────────────────────

up:
    docker compose up -d

down:
    docker compose down

logs:
    docker compose logs -f

ps:
    docker compose ps

# ── Celery ──────────────────────────────────────────

worker:
    cd $BACKEND_DIR && $py_run celery -A celery_app worker -l info

beat:
    cd $BACKEND_DIR && $py_run celery -A celery_app beat -l info

# ── Neon DB ─────────────────────────────────────────

neon-branches:
    neonctl branches list

neon-create-branch name:
    neonctl branches create --name {{name}}

neon-connect:
    neonctl connection-string

# ── Alles zusammen ──────────────────────────────────

dev:
    #!/usr/bin/env bash
    trap 'kill 0' EXIT
    docker compose up -d
    just backend &
    just frontend &
    wait

setup:
    ./setup.sh

check:
    ./setup.sh --check

test: test-backend lint-backend lint-frontend

[confirm("Wirklich DB zurücksetzen?")]
reset-db:
    cd $BACKEND_DIR && $py_run manage.py flush --noinput
    just migrate
EOF

    success "justfile erstellt"
}

# ============================================================
# CLEAN
# ============================================================

do_clean() {
    warn "⚠️  Entfernt: $BACKEND_DIR/, $FRONTEND_DIR/, .env, justfile, docker-compose.yml, .github/"
    read -rp "Fortfahren? (y/N): " confirm
    [[ "$confirm" =~ ^[yY]$ ]] || { info "Abgebrochen"; return 0; }

    rm -rf "$BACKEND_DIR" "$FRONTEND_DIR" \
        .env .env.example justfile \
        docker-compose.yml .pre-commit-config.yaml \
        .github "$BACKEND_DIR/Dockerfile" "$BACKEND_DIR/celery_app.py"
    success "Projektdateien entfernt"
}

# ============================================================
# MAIN
# ============================================================

main() {
    echo ""
    echo "🚀 $PROJECT_NAME — Setup Tool v2"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if $CLEAN; then do_clean; exit 0; fi

    print_status

    if $CHECK_ONLY; then exit 0; fi

    # Phase 1: Kern-Tools
    log "━━━ Phase 1: Kern-Abhängigkeiten ━━━"
    install_python
    install_node
    install_uv
    install_node_pkg_manager
    echo ""

    # Phase 2: Services & Tools
    log "━━━ Phase 2: Services & Tools ━━━"
    install_docker
    install_neon_cli
    install_redis
    install_just
    install_ruff
    echo ""

    # Phase 3: Projekt-Struktur
    log "━━━ Phase 3: Projekt-Setup ━━━"
    setup_backend
    setup_frontend
    echo ""

    # Phase 4: Docker
    log "━━━ Phase 4: Docker Config ━━━"
    generate_docker_compose
    generate_backend_dockerfile
    echo ""

    # Phase 5: Celery
    log "━━━ Phase 5: Task Queue ━━━"
    setup_celery
    echo ""

    # Phase 6: CI/CD
    log "━━━ Phase 6: CI/CD ━━━"
    setup_github_actions
    echo ""

    # Phase 7: Konfiguration
    log "━━━ Phase 7: Konfiguration ━━━"
    setup_env_file
    setup_git
    setup_precommit
    generate_justfile
    echo ""

    # Finaler Status
    print_status

    success "🎉 Setup abgeschlossen!"
    echo ""
    info "Nächste Schritte:"
    echo "  1. nano .env                  → Variablen anpassen"
    echo "  2. just up                    → Docker Services starten"
    echo "  3. just dev                   → Backend + Frontend starten"
    echo "  4. just migrate               → Datenbank migrieren"
    [ "${NEON_CLI:-false}" = "true" ] && echo "  5. neonctl auth                → Bei Neon einloggen"
    echo ""
}

main
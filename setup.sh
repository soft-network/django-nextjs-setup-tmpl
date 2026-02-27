#!/usr/bin/env bash
# ============================================================
# setup.sh — Intelligentes Projekt-Setup-Tool
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
NC='\033[0m' # No Color

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
            echo "  --dry-run   Zeigt was passieren würde, ohne Änderungen"
            echo "  --check     Prüft nur den Status aller Abhängigkeiten"
            echo "  --clean     Entfernt generierte Projektverzeichnisse"
            exit 0
            ;;
        *)
            error "Unbekanntes Argument: $arg"
            exit 1
            ;;
    esac
done

# === Config laden ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/project.conf"

if [ ! -f "$CONF_FILE" ]; then
    error "project.conf nicht gefunden in: $SCRIPT_DIR"
    error "Erstelle eine project.conf neben diesem Script."
    exit 1
fi

# shellcheck source=project.conf
source "$CONF_FILE"

# === OS-Erkennung ===
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt &>/dev/null; then
            echo "debian"
        elif command -v dnf &>/dev/null; then
            echo "fedora"
        elif command -v pacman &>/dev/null; then
            echo "arch"
        else
            echo "linux-unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

OS_TYPE=$(detect_os)
log "Betriebssystem erkannt: $OS_TYPE"

# === Hilfsfunktionen ===
cmd_exists() { command -v "$1" &>/dev/null; }

get_version() {
    local cmd="$1"
    if cmd_exists "$cmd"; then
        case "$cmd" in
            python3) python3 --version 2>&1 | awk '{print $2}' ;;
            node)    node --version 2>&1 | sed 's/^v//' ;;
            uv)      uv --version 2>&1 | awk '{print $2}' ;;
            pnpm)    pnpm --version 2>&1 ;;
            npm)     npm --version 2>&1 ;;
            git)     git --version 2>&1 | awk '{print $3}' ;;
            *)       echo "unknown" ;;
        esac
    else
        echo "nicht installiert"
    fi
}

# Versionsprüfung: ist installierte Version >= gewünschte?
version_gte() {
    # $1 = installierte Version, $2 = gewünschte Mindestversion
    printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1 | grep -q "^$2$"
}

run_or_dry() {
    if $DRY_RUN; then
        info "[DRY-RUN] Würde ausführen: $*"
    else
        "$@"
    fi
}

pkg_install() {
    local pkg="$1"
    case "$OS_TYPE" in
        debian)
            run_or_dry sudo apt-get install -y "$pkg"
            ;;
        fedora)
            run_or_dry sudo dnf install -y "$pkg"
            ;;
        arch)
            run_or_dry sudo pacman -S --noconfirm "$pkg"
            ;;
        macos)
            if ! cmd_exists brew; then
                error "Homebrew nicht gefunden. Bitte installiere es: https://brew.sh"
                return 1
            fi
            run_or_dry brew install "$pkg"
            ;;
        *)
            error "Kann $pkg nicht automatisch installieren auf: $OS_TYPE"
            return 1
            ;;
    esac
}

# ============================================================
# STATUS-CHECK: Was ist bereits installiert?
# ============================================================
print_status() {
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║         📋 UMGEBUNGS-STATUS                      ║"
    echo "╠══════════════════════════════════════════════════╣"

    local tools=("python3" "node" "git" "uv" "pnpm" "npm")
    for tool in "${tools[@]}"; do
        local ver
        ver=$(get_version "$tool")
        if cmd_exists "$tool"; then
            printf "║  %-12s ✅  %-30s ║\n" "$tool" "$ver"
        else
            printf "║  %-12s ❌  %-30s ║\n" "$tool" "nicht installiert"
        fi
    done

    echo "╠══════════════════════════════════════════════════╣"
    echo "║         📁 PROJEKT-STRUKTUR                      ║"
    echo "╠══════════════════════════════════════════════════╣"

    if [ -d "$BACKEND_DIR" ] && [ -f "$BACKEND_DIR/pyproject.toml" ]; then
        printf "║  %-12s ✅  %-30s ║\n" "Backend" "konfiguriert"
    else
        printf "║  %-12s ❌  %-30s ║\n" "Backend" "nicht eingerichtet"
    fi

    if [ -d "$FRONTEND_DIR" ] && [ -f "$FRONTEND_DIR/package.json" ]; then
        printf "║  %-12s ✅  %-30s ║\n" "Frontend" "konfiguriert"
    else
        printf "║  %-12s ❌  %-30s ║\n" "Frontend" "nicht eingerichtet"
    fi

    echo "╚══════════════════════════════════════════════════╝"
    echo ""
}

# ============================================================
# INSTALLATIONEN
# ============================================================

install_python() {
    if cmd_exists python3; then
        local current
        current=$(get_version python3)
        if version_gte "$current" "$PYTHON_VER"; then
            success "Python $current (>= $PYTHON_VER benötigt)"
            return 0
        else
            warn "Python $current installiert, aber $PYTHON_VER gewünscht"
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
        local current
        current=$(get_version node)
        local wanted="${NODE_VER}"
        [ "$wanted" = "latest" ] && wanted="20"  # Fallback LTS

        if version_gte "$current" "$wanted"; then
            success "Node.js v$current (>= v$wanted benötigt)"
            return 0
        else
            warn "Node.js v$current installiert, aber v$wanted gewünscht"
        fi
    fi

    log "Installiere Node.js..."
    case "$OS_TYPE" in
        debian|fedora)
            local node_major="${NODE_VER}"
            [ "$node_major" = "latest" ] && node_major="22"
            if cmd_exists curl; then
                run_or_dry bash -c "curl -fsSL https://deb.nodesource.com/setup_${node_major}.x | sudo -E bash -"
                pkg_install "nodejs"
            else
                error "curl wird benötigt um Node.js zu installieren"
                return 1
            fi
            ;;
        arch)   pkg_install "nodejs" && pkg_install "npm" ;;
        macos)  pkg_install "node" ;;
    esac
}

install_uv() {
    if cmd_exists uv; then
        success "uv $(get_version uv)"
        return 0
    fi

    if [ "$PYTHON_PKG_MANAGER" != "uv" ]; then
        info "uv übersprungen (PYTHON_PKG_MANAGER=$PYTHON_PKG_MANAGER)"
        return 0
    fi

    log "Installiere uv..."
    if cmd_exists curl; then
        run_or_dry bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh"
        # uv installiert sich nach ~/.local/bin
        export PATH="$HOME/.local/bin:$PATH"
    else
        error "curl wird benötigt um uv zu installieren"
        return 1
    fi
}

install_node_pkg_manager() {
    local mgr="${NODE_PKG_MANAGER:-pnpm}"

    if [ "$mgr" = "npm" ]; then
        success "npm $(get_version npm) (Standard)"
        return 0
    fi

    if cmd_exists "$mgr"; then
        success "$mgr $(get_version "$mgr")"
        return 0
    fi

    log "Installiere $mgr..."
    case "$mgr" in
        pnpm)
            if cmd_exists corepack; then
                run_or_dry corepack enable
                run_or_dry corepack prepare pnpm@latest --activate
            else
                run_or_dry npm install -g pnpm
            fi
            ;;
        yarn)
            run_or_dry npm install -g yarn
            ;;
    esac
}

# ============================================================
# PROJEKT-SETUP
# ============================================================

setup_backend() {
    log "━━━ Backend Setup ($BACKEND_DIR) ━━━"

    run_or_dry mkdir -p "$BACKEND_DIR"

    if [ -f "$BACKEND_DIR/pyproject.toml" ]; then
        success "Backend bereits initialisiert — überspringe"
        return 0
    fi

    if $DRY_RUN; then
        info "[DRY-RUN] Würde Backend mit Django $DJANGO_VER initialisieren"
        return 0
    fi

    cd "$BACKEND_DIR"

    case "$PYTHON_PKG_MANAGER" in
        uv)
            uv init --python "$PYTHON_VER" 2>/dev/null || true

            # Django installieren
            local django_spec="django"
            if [ "${DJANGO_VER:-latest}" != "latest" ]; then
                django_spec="django==${DJANGO_VER}.*"
            fi
            uv add "$django_spec"

            # Extras installieren
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

            if [ -n "${PYTHON_EXTRAS:-}" ]; then
                pip install $PYTHON_EXTRAS
            fi
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

    if $DRY_RUN; then
        info "[DRY-RUN] Würde Frontend mit Next.js $NEXTJS_VER initialisieren"
        return 0
    fi

    local npx_cmd="npx"
    [ "$NODE_PKG_MANAGER" = "pnpm" ] && npx_cmd="pnpm dlx"

    # Next.js Projekt erstellen
    local nextjs_spec="create-next-app"
    if [ "${NEXTJS_VER:-latest}" != "latest" ]; then
        nextjs_spec="create-next-app@${NEXTJS_VER}"
    fi

    $npx_cmd $nextjs_spec "$FRONTEND_DIR" \
        --typescript \
        --tailwind \
        --eslint \
        --app \
        --src-dir \
        --import-alias "@/*" \
        --use-${NODE_PKG_MANAGER:-pnpm} \
        2>/dev/null || {
            error "Next.js Setup fehlgeschlagen"
            return 1
        }

    # Extras installieren
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

setup_env_file() {
    if [ "${SETUP_ENV_FILE:-false}" != "true" ]; then return 0; fi

    if [ -f ".env" ]; then
        success ".env existiert bereits"
        return 0
    fi

    log "Erstelle .env Template..."
    if ! $DRY_RUN; then
        cat > .env << 'EOF'
# ============================================================
# Umgebungsvariablen — NICHT in Git committen!
# Kopiere diese Datei als .env und passe die Werte an.
# ============================================================

# Django
DJANGO_SECRET_KEY=change-me-to-a-random-string
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1

# Datenbank
DATABASE_URL=postgresql://user:password@localhost:5432/dbname

# Redis (falls aktiviert)
REDIS_URL=redis://localhost:6379/0

# Next.js
NEXT_PUBLIC_API_URL=http://localhost:8000/api

# AI / Externe APIs
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
EOF
        success ".env Template erstellt"
    fi
}

setup_git() {
    if [ "${SETUP_GIT:-false}" != "true" ]; then return 0; fi

    if [ -d ".git" ]; then
        success "Git-Repo existiert bereits"
        return 0
    fi

    log "Initialisiere Git-Repo..."
    if ! $DRY_RUN; then
        git init

        # .gitignore erstellen
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

# Build
dist/
build/
*.log
EOF
        success ".gitignore erstellt"
    fi
}

setup_precommit() {
    if [ "${SETUP_PRECOMMIT:-false}" != "true" ]; then return 0; fi
    if [ -f ".pre-commit-config.yaml" ]; then
        success "Pre-commit bereits konfiguriert"
        return 0
    fi

    log "Erstelle Pre-commit Config..."
    if ! $DRY_RUN; then
        cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
EOF
        success "Pre-commit Config erstellt"
    fi
}

# ============================================================
# JUSTFILE GENERIEREN
# ============================================================

generate_justfile() {
    if [ -f "justfile" ]; then
        success "justfile existiert bereits"
        return 0
    fi

    log "Generiere justfile..."
    if $DRY_RUN; then
        info "[DRY-RUN] Würde justfile erstellen"
        return 0
    fi

    local py_run="uv run"
    [ "$PYTHON_PKG_MANAGER" = "pip" ] && py_run=".venv/bin/python"

    local nd_run="pnpm"
    [ "$NODE_PKG_MANAGER" = "npm" ] && nd_run="npm run"
    [ "$NODE_PKG_MANAGER" = "yarn" ] && nd_run="yarn"

    cat > justfile << EOF
# ============================================================
# justfile — Projekt-Kommandos für $PROJECT_NAME
# Usage: just <command>
# ============================================================

# Standardrezept: zeige alle verfügbaren Kommandos
default:
    @just --list

# ── Backend ─────────────────────────────────────────

# Django Dev-Server starten
backend:
    cd $BACKEND_DIR && $py_run manage.py runserver

# Django Migrationen erstellen und anwenden
migrate:
    cd $BACKEND_DIR && $py_run manage.py makemigrations
    cd $BACKEND_DIR && $py_run manage.py migrate

# Django Superuser erstellen
superuser:
    cd $BACKEND_DIR && $py_run manage.py createsuperuser

# Django Shell öffnen
shell:
    cd $BACKEND_DIR && $py_run manage.py shell

# Python Tests ausführen
test-backend:
    cd $BACKEND_DIR && $py_run manage.py test

# Ruff Linting + Formatting
lint-backend:
    cd $BACKEND_DIR && $py_run ruff check . --fix
    cd $BACKEND_DIR && $py_run ruff format .

# ── Frontend ────────────────────────────────────────

# Next.js Dev-Server starten
frontend:
    cd $FRONTEND_DIR && $nd_run dev

# Next.js Build
build-frontend:
    cd $FRONTEND_DIR && $nd_run build

# Frontend Linting
lint-frontend:
    cd $FRONTEND_DIR && $nd_run lint

# ── Alles zusammen ──────────────────────────────────

# Beide Dev-Server parallel starten
dev:
    #!/usr/bin/env bash
    trap 'kill 0' EXIT
    just backend &
    just frontend &
    wait

# Setup: Umgebung prüfen und vorbereiten
setup:
    ./setup.sh

# Setup: Nur Status prüfen
check:
    ./setup.sh --check

# Alles testen
test: test-backend lint-backend lint-frontend

# Datenbank zurücksetzen (Vorsicht!)
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
    warn "⚠️  Dies entfernt: $BACKEND_DIR/, $FRONTEND_DIR/, .env, justfile"
    read -rp "Wirklich fortfahren? (y/N): " confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        rm -rf "$BACKEND_DIR" "$FRONTEND_DIR" .env justfile .pre-commit-config.yaml
        success "Projektdateien entfernt"
    else
        info "Abgebrochen"
    fi
}

# ============================================================
# MAIN
# ============================================================

main() {
    echo ""
    echo "🚀 $PROJECT_NAME — Setup Tool"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if $CLEAN; then
        do_clean
        exit 0
    fi

    # Immer: Status anzeigen
    print_status

    if $CHECK_ONLY; then
        exit 0
    fi

    # Phase 1: System-Tools
    log "━━━ Phase 1: System-Abhängigkeiten ━━━"
    install_python
    install_node
    install_uv
    install_node_pkg_manager

    echo ""

    # Phase 2: Projekt-Struktur
    log "━━━ Phase 2: Projekt-Setup ━━━"
    setup_backend
    setup_frontend

    echo ""

    # Phase 3: Extras
    log "━━━ Phase 3: Konfiguration ━━━"
    setup_env_file
    setup_git
    setup_precommit
    generate_justfile

    echo ""

    # Finaler Status
    print_status

    echo ""
    success "🎉 Setup abgeschlossen!"
    echo ""
    info "Nächste Schritte:"
    echo "  1. Passe .env an deine Umgebung an"
    echo "  2. just dev    — Startet beide Dev-Server"
    echo "  3. just migrate — Erstellt die Datenbank"
    echo ""
}

main
# 🛠️ Django + Next.js Setup Template

Intelligentes, idempotentes Setup-Tool für Full-Stack SaaS Projekte.
Einmal klonen → konfigurieren → `./setup.sh` → loslegen.

## Stack

| Layer | Technologie |
|---|---|
| Backend | Python, Django, Django Ninja, Celery |
| Frontend | Next.js, TypeScript, Tailwind CSS |
| Datenbank | Neon (Cloud) oder PostgreSQL (Docker) |
| Cache/Queue | Redis |
| Paketmanager | uv (Python), pnpm (Node) |
| CI/CD | GitHub Actions |
| DevTools | just, Ruff, Pre-commit |

## Quickstart

```bash
# Neues Projekt aus Template erstellen
gh repo create mein-projekt --template soft-network/django-nextjs-setup-tmpl --public --clone
cd mein-projekt

# Konfiguration anpassen
nano project.conf

# Setup — installiert alles was fehlt
chmod +x setup.sh
./setup.sh

# Loslegen
just dev
```

## Was `setup.sh` macht

| Phase | Aktion |
|---|---|
| 1. Kern | Python, Node.js, uv, pnpm prüfen & installieren |
| 2. Services | Docker, Neon CLI, Redis, just, Ruff |
| 3. Projekt | Django Backend + Next.js Frontend aufsetzen |
| 4. Docker | docker-compose.yml + Dockerfile generieren |
| 5. Queue | Celery Konfiguration |
| 6. CI/CD | GitHub Actions Pipeline |
| 7. Config | .env, .gitignore, justfile, Pre-commit |

## Kommandos

```bash
./setup.sh              # Vollständiges Setup
./setup.sh --check      # Nur Status anzeigen
./setup.sh --dry-run    # Zeigt was passieren würde
./setup.sh --clean      # Generierte Dateien entfernen
```

## Tägliche Arbeit mit `just`

```bash
just                    # Alle Befehle anzeigen
just dev                # Backend + Frontend + Docker starten
just backend            # Nur Django
just frontend           # Nur Next.js
just migrate            # DB Migrationen
just up / just down     # Docker Services
just worker             # Celery Worker
just test               # Alle Tests + Linting
just neon-branches      # Neon DB Branches anzeigen
```

## Dateien

```
├── project.conf           ← Konfiguration (pro Projekt anpassen)
├── setup.sh               ← Haupt-Setup-Script
├── README.md              ← Diese Datei
│
│   ── Wird generiert von setup.sh ──
├── .env                   ← Umgebungsvariablen
├── .gitignore
├── .pre-commit-config.yaml
├── justfile               ← Task Runner Befehle
├── docker-compose.yml     ← Postgres + Redis
├── .github/workflows/ci.yml
├── backend/
│   ├── pyproject.toml
│   ├── Dockerfile
│   ├── celery_app.py
│   └── manage.py
└── frontend/
    ├── package.json
    ├── src/
    └── ...
```
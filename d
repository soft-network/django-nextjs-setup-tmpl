[1mdiff --git a/README.md b/README.md[m
[1mindex 5765552..2dce3d3 100644[m
[1m--- a/README.md[m
[1m+++ b/README.md[m
[36m@@ -1,62 +1,94 @@[m
[32m+[m[32m# 🛠️ Django + Next.js Setup Template[m
 [m
[31m-# 🛠️ Projekt-Setup-Toolbox[m
[32m+[m[32mIntelligentes, idempotentes Setup-Tool für Full-Stack SaaS Projekte.[m
[32m+[m[32mEinmal klonen → konfigurieren → `./setup.sh` → loslegen.[m
 [m
[31m-Intelligentes, idempotentes Setup-Tool für Django + Next.js Projekte.[m
[31m-In Git gespeichert — einmal klonen, in jedes Projekt importieren.[m
[32m+[m[32m## Stack[m
 [m
[31m-## Dateien[m
[31m-[m
[31m-| Datei | Zweck |[m
[32m+[m[32m| Layer | Technologie |[m
 |---|---|[m
[31m-| `project.conf` | Projektkonfiguration (Versionen, Extras, Features) |[m
[31m-| `setup.sh` | Hauptscript — erkennt, installiert, konfiguriert |[m
[31m-| `justfile` | Wird automatisch generiert — Task Runner |[m
[32m+[m[32m| Backend | Python, Django, Django Ninja, Celery |[m
[32m+[m[32m| Frontend | Next.js, TypeScript, Tailwind CSS |[m
[32m+[m[32m| Datenbank | Neon (Cloud) oder PostgreSQL (Docker) |[m
[32m+[m[32m| Cache/Queue | Redis |[m
[32m+[m[32m| Paketmanager | uv (Python), pnpm (Node) |[m
[32m+[m[32m| CI/CD | GitHub Actions |[m
[32m+[m[32m| DevTools | just, Ruff, Pre-commit |[m
 [m
 ## Quickstart[m
 [m
 ```bash[m
[31m-# 1. Toolbox klonen / kopieren[m
[31m-git clone <dein-toolbox-repo> && cd mein-projekt[m
[31m-cp ../toolbox/{project.conf,setup.sh} .[m
[32m+[m[32m# Neues Projekt aus Template erstellen[m
[32m+[m[32mgh repo create mein-projekt --template soft-network/django-nextjs-setup-tmpl --public --clone[m
[32m+[m[32mcd mein-projekt[m
 [m
[31m-# 2. Konfiguration anpassen[m
[32m+[m[32m# Konfiguration anpassen[m
 nano project.conf[m
 [m
[31m-# 3. Setup ausführen[m
[32m+[m[32m# Setup — installiert alles was fehlt[m
 chmod +x setup.sh[m
 ./setup.sh[m
[32m+[m
[32m+[m[32m# Loslegen[m
[32m+[m[32mjust dev[m
 ```[m
 [m
[32m+[m[32m## Was `setup.sh` macht[m
[32m+[m
[32m+[m[32m| Phase | Aktion |[m
[32m+[m[32m|---|---|[m
[32m+[m[32m| 1. Kern | Python, Node.js, uv, pnpm prüfen & installieren |[m
[32m+[m[32m| 2. Services | Docker, Neon CLI, Redis, just, Ruff |[m
[32m+[m[32m| 3. Projekt | Django Backend + Next.js Frontend aufsetzen |[m
[32m+[m[32m| 4. Docker | docker-compose.yml + Dockerfile generieren |[m
[32m+[m[32m| 5. Queue | Celery Konfiguration |[m
[32m+[m[32m| 6. CI/CD | GitHub Actions Pipeline |[m
[32m+[m[32m| 7. Config | .env, .gitignore, justfile, Pre-commit |[m
[32m+[m
 ## Kommandos[m
 [m
 ```bash[m
 ./setup.sh              # Vollständiges Setup[m
[31m-./setup.sh --check      # Nur Status prüfen (ändert nichts)[m
[32m+[m[32m./setup.sh --check      # Nur Status anzeigen[m
 ./setup.sh --dry-run    # Zeigt was passieren würde[m
 ./setup.sh --clean      # Generierte Dateien entfernen[m
 ```[m
 [m
[31m-## Was das Script macht[m
[32m+[m[32m## Tägliche Arbeit mit `just`[m
 [m
[31m-### Phase 1 — System-Abhängigkeiten[m
[31m-- Erkennt das Betriebssystem (Debian/Fedora/Arch/macOS)[m
[31m-- Prüft Python, Node.js, uv, pnpm Versionen[m
[31m-- Installiert nur was fehlt oder veraltet ist[m
[31m-[m
[31m-### Phase 2 — Projekt-Struktur[m
[31m-- Backend: `uv init` + Django + konfigurierte Extras[m
[31m-- Frontend: `create-next-app` mit TypeScript + Tailwind[m
[31m-[m
[31m-### Phase 3 — Konfiguration[m
[31m-- `.env` Template mit allen nötigen Variablen[m
[31m-- `.gitignore` für Python + Node + IDE[m
[31m-- Pre-commit Hooks (Ruff Linter/Formatter)[m
[31m-- `justfile` mit allen wichtigen Dev-Kommandos[m
[32m+[m[32m```bash[m
[32m+[m[32mjust                    # Alle Befehle anzeigen[m
[32m+[m[32mjust dev                # Backend + Frontend + Docker starten[m
[32m+[m[32mjust backend            # Nur Django[m
[32m+[m[32mjust frontend           # Nur Next.js[m
[32m+[m[32mjust migrate            # DB Migrati
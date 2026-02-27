
# 🛠️ Projekt-Setup-Toolbox

Intelligentes, idempotentes Setup-Tool für Django + Next.js Projekte.
In Git gespeichert — einmal klonen, in jedes Projekt importieren.

## Dateien

| Datei | Zweck |
|---|---|
| `project.conf` | Projektkonfiguration (Versionen, Extras, Features) |
| `setup.sh` | Hauptscript — erkennt, installiert, konfiguriert |
| `justfile` | Wird automatisch generiert — Task Runner |

## Quickstart

```bash
# 1. Toolbox klonen / kopieren
git clone <dein-toolbox-repo> && cd mein-projekt
cp ../toolbox/{project.conf,setup.sh} .

# 2. Konfiguration anpassen
nano project.conf

# 3. Setup ausführen
chmod +x setup.sh
./setup.sh
```

## Kommandos

```bash
./setup.sh              # Vollständiges Setup
./setup.sh --check      # Nur Status prüfen (ändert nichts)
./setup.sh --dry-run    # Zeigt was passieren würde
./setup.sh --clean      # Generierte Dateien entfernen
```

## Was das Script macht

### Phase 1 — System-Abhängigkeiten
- Erkennt das Betriebssystem (Debian/Fedora/Arch/macOS)
- Prüft Python, Node.js, uv, pnpm Versionen
- Installiert nur was fehlt oder veraltet ist

### Phase 2 — Projekt-Struktur
- Backend: `uv init` + Django + konfigurierte Extras
- Frontend: `create-next-app` mit TypeScript + Tailwind

### Phase 3 — Konfiguration
- `.env` Template mit allen nötigen Variablen
- `.gitignore` für Python + Node + IDE
- Pre-commit Hooks (Ruff Linter/Formatter)
- `justfile` mit allen wichtigen Dev-Kommandos

## Design-Prinzipien

- **Idempotent**: Kann beliebig oft ausgeführt werden — überspringt was schon da ist
- **OS-agnostisch**: Unterstützt apt, dnf, pacman, brew
- **Dry-Run**: Zeigt Änderungen bevor sie passieren
- **Konfigurierbar**: Alles in `project.conf`, kein Hardcoding
- **Fehler-transparent**: Farbige Logs, keine verschluckten Fehler
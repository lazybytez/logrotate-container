# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lightweight side-car container that auto-discovers log files and rotates them using logrotate. Available as Alpine, Debian, and UBI (Red Hat) flavours. Designed to attach to workloads writing logs to disk. Originally forked from blacklabelops/logrotate, now maintained by Lazy Bytez.

## Build & Run

```bash
# Build the container image (alpine, debian, or ubi)
docker build -f Containerfile.alpine -t logrotate-container .
docker build -f Containerfile.debian -t logrotate-container .
docker build -f Containerfile.ubi -t logrotate-container .

# Build with specific args (logrotate_version only works with Alpine)
docker build -f Containerfile.alpine -t logrotate-container \
  --build-arg image_version=1.0.0 \
  --build-arg logrotate_version=latest .

# Run locally for testing
docker run -d \
  -e LOGS_DIRECTORIES="/var/log" \
  -e LOGROTATE_INTERVAL="daily" \
  -v /path/to/logs:/var/log \
  logrotate-container
```

## E2E Tests

```bash
# Run all test suites (default: alpine)
./e2e/run-tests.sh

# Run a specific flavour
CONTAINERFILE=Containerfile.debian ./e2e/run-tests.sh
CONTAINERFILE=Containerfile.ubi ./e2e/run-tests.sh

# Run a single suite
./e2e/run-tests.sh 01_config_generation

# Use podman instead of docker
CONTAINER_RUNTIME=podman ./e2e/run-tests.sh
```

Tests require a container runtime (docker or podman). The runner builds the image, then executes each suite in `e2e/tests/`. Each suite sources `e2e/lib/helpers.sh` for assertions and container lifecycle management.

**Suites:** config generation, file discovery, rotation settings, compression, scheduling, pre/post rotate, file ownership, actual rotation, edge cases.

## Architecture

**Runtime flow:** `tini` (PID 1) → `container-entrypoint.sh` → generates logrotate config → starts `ofelia` cron daemon

**Key components:**

| File | Purpose |
|---|---|
| `Containerfile.alpine` | Alpine-based image (default), uses apk |
| `Containerfile.debian` | Debian bookworm-slim image, uses apt |
| `Containerfile.ubi` | UBI 9 minimal image, uses microdnf |
| `container-entrypoint.sh` | Startup orchestrator: sources helpers, generates config, resolves cron schedule, launches ofelia |
| `logrotate.d/logrotate.sh` | Helper functions resolving env vars to logrotate directives (compression, sizing, rotation mode) |
| `logrotate.d/logrotate-config.sh` | Creates individual logrotate config entries with proper ownership (`su user group`) |
| `logrotate.d/logrotate-create-config.sh` | File discovery engine: finds logs by extension or regex in specified directories |
| `logrotate.d/update-logrotate.sh` | Config regeneration script (used when `LOGROTATE_AUTOUPDATE=true`) |

**Config generation pipeline:**
1. `logrotate-create-config.sh` discovers files matching `LOG_FILE_ENDINGS` or `LOGS_FILE_REGEX` in `LOGS_DIRECTORIES`
2. For each file, `logrotate-config.sh` creates a logrotate block using directives resolved by `logrotate.sh`
3. All blocks are written to `/usr/bin/logrotate.d/logrotate.conf`
4. Ofelia runs logrotate on that config at the configured interval

**Key design decisions:**
- Ofelia over crond for lighter, more reliable job scheduling
- Tini for proper PID 1 signal handling (zombie reaping, signal forwarding)
- `LOGROTATE_AUTOUPDATE=true` (default) re-runs discovery each cron cycle to pick up new log files without restart

## Code Conventions

- **Language:** Bash shell scripts (no compiled code)
- **Shell indentation:** 2 spaces (per .editorconfig)
- **Containerfile indentation:** Tabs
- **YAML indentation:** 2 spaces
- **Line endings:** LF, UTF-8, max 120 chars (except markdown/yaml)
- **Commits:** Conventional Commits, 50-char subject max. Types: `feat`, `fix`, `build`, `chore`, `ci`, `docs`, `perf`, `refactor`, `revert`, `style`, `test`

## CI/CD

- **git.yml** — PR validation: branch naming (`feature|hotfix|release|renovate/*`) + commitlint
- **e2e.yml** — Runs e2e test suites for all flavours (alpine, debian, ubi) on PRs and pushes to `main`
- **build_edge.yml** — Push to `main` → builds `edge` tags for all flavours to ghcr.io and git.lazybytez.cloud
- **build_production.yml** — Semver tag (`v*.*.*`) → builds versioned tags for all flavours
- All builds are multi-platform: `linux/amd64`, `linux/arm64`
- **Tag convention:** Alpine has no suffix (default), others use `-debian`/`-ubi` (e.g., `1.2.3`, `1.2.3-debian`, `1.2.3-ubi`)

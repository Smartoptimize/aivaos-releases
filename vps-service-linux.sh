#!/usr/bin/env bash
# AIVAOS VPS service installer (Linux, systemd).
#
# Turns an already-installed AIVAOS localhost server (from install-linux.sh)
# into a boot-persistent, auto-restarting systemd service. This is the "stays on
# and comes back after a reboot" piece a founder needs to run AIVAOS on a VPS
# and reach it in the browser day after day.
#
# It does NOT open any public port. The service binds loopback (127.0.0.1:25808)
# by default — exactly like the app's own safe default (see
# resolveStandaloneServerConfig: it refuses a non-loopback bind without
# ALLOW_REMOTE=true). You reach it over an SSH tunnel, or put nginx + TLS in
# front (see docs/VPS_WINDOWS_FOUNDER_RUNBOOK.md). Raw public exposure is an
# explicit, deliberate opt-in, never the default.
#
# Prereq: run scripts/install/install-linux.sh first (creates ~/.founderos/current).
#
# Usage:
#   bash scripts/install/vps-service-linux.sh            # install + start (loopback)
#   ALLOW_REMOTE=true bash scripts/install/vps-service-linux.sh   # bind 0.0.0.0 (only behind a firewall/proxy)
#   PORT=28080 bash scripts/install/vps-service-linux.sh # custom port
#
# Uninstall:
#   systemctl --user disable --now founderos.service && rm ~/.config/systemd/user/founderos.service
set -euo pipefail

APP_ID="founderos"
INSTALL_DIR="${FOUNDEROS_INSTALL_DIR:-$HOME/.founderos}"
CURRENT_LINK="${INSTALL_DIR}/current"
PORT="${PORT:-25808}"
# Safe default: loopback only. Set ALLOW_REMOTE=true ONLY when a firewall or
# reverse proxy protects the box — the server itself will refuse a public bind
# without this, on purpose.
ALLOW_REMOTE="${ALLOW_REMOTE:-false}"
UNIT_DIR="${HOME}/.config/systemd/user"
UNIT_PATH="${UNIT_DIR}/${APP_ID}.service"

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

command -v systemctl >/dev/null 2>&1 || fail "systemctl not found. This installer needs systemd (standard on Ubuntu 22.04/24.04)."
[[ -x "${CURRENT_LINK}/start.sh" ]] || fail "AIVAOS is not installed at ${CURRENT_LINK}. Run scripts/install/install-linux.sh first."

BUN_BIN="$(command -v bun || true)"
[[ -n "$BUN_BIN" ]] || fail "bun not found on PATH. install-linux.sh installs it to ~/.bun/bin — open a new shell or add it to PATH, then retry."
BUN_DIR="$(dirname "$BUN_BIN")"

mkdir -p "$UNIT_DIR"

# NOTE: start.sh reads PORT/ALLOW_REMOTE from the environment and execs
# `bun dist-server/server.mjs`. We point WorkingDirectory at the resolved
# install (following the `current` symlink) so `dist-server/` is found.
RESOLVED_DIR="$(cd "$CURRENT_LINK" && pwd -P)"

cat >"$UNIT_PATH" <<UNIT
[Unit]
Description=AIVAOS localhost server (browser UI)
Documentation=file://${HOME}/.founderos/current/README.md
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${RESOLVED_DIR}
Environment=NODE_ENV=production
Environment=IS_PACKAGED=true
Environment=PORT=${PORT}
Environment=ALLOW_REMOTE=${ALLOW_REMOTE}
Environment=FOUNDEROS_OPEN_BROWSER=0
Environment=PATH=${BUN_DIR}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# start.sh does the bun-present check, first-run install, and execs the server.
ExecStart=/usr/bin/env bash ${RESOLVED_DIR}/start.sh
Restart=always
RestartSec=3
# Give first-run `bun install --production` room before systemd calls it failed.
TimeoutStartSec=300

[Install]
WantedBy=default.target
UNIT

# Reload, enable at boot, (re)start now.
systemctl --user daemon-reload
systemctl --user enable "${APP_ID}.service"
systemctl --user restart "${APP_ID}.service"

# Linger keeps the user service running after logout and across reboots without
# an active login session — essential on a headless VPS.
if command -v loginctl >/dev/null 2>&1; then
  loginctl enable-linger "$(id -un)" >/dev/null 2>&1 || \
    printf 'Note: could not enable linger automatically. Run: sudo loginctl enable-linger %s\n' "$(id -un)"
fi

printf '\n'
printf 'AIVAOS is now a boot-persistent service.\n'
printf '  Bind:    %s:%s\n' "$([[ "$ALLOW_REMOTE" == "true" ]] && echo 0.0.0.0 || echo 127.0.0.1)" "$PORT"
printf '  Status:  systemctl --user status %s\n' "$APP_ID"
printf '  Logs:    journalctl --user -u %s -f\n' "$APP_ID"
printf '  Restart: systemctl --user restart %s\n' "$APP_ID"
printf '\n'
if [[ "$ALLOW_REMOTE" != "true" ]]; then
  printf 'It is bound to loopback (the safe default). Reach it from your Windows PC with:\n'
  printf '  ssh -L %s:127.0.0.1:%s USER@YOUR_SERVER_IP\n' "$PORT" "$PORT"
  printf 'then open http://localhost:%s in your browser.\n' "$PORT"
  printf 'For a bookmarkable https:// address, see docs/VPS_WINDOWS_FOUNDER_RUNBOOK.md.\n'
fi

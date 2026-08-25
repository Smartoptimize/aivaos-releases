#!/usr/bin/env bash
# AIVAOS VPS one-command update (Linux).
#
# Re-installs the latest AIVAOS server bundle from the public release feed and
# restarts the systemd service, so a founder stays current with one command.
#
# How "latest" is resolved (honest, no magic):
#   1. If FOUNDEROS_BUNDLE_URL is set, that exact bundle is installed.
#   2. Else it queries the GitHub Releases API for the newest tag on
#      Smartoptimize/aivaos-releases and installs that version's bundle.
#      This MUST NOT be changed to any other feed: this script installs whatever the
#      newest tag there points at, so a wrong feed would silently pull a different
#      product's bundle over this VPS on the next update run. This file is published
#      verbatim to the public release repo, so it names no other product.
#   3. Else (offline / API unreachable) it re-runs the bundled install-linux.sh
#      as-is, which pins the version baked into that script.
#
# The install itself is atomic: install-linux.sh downloads, verifies SHA256SUMS,
# extracts to ~/.founderos/vX.Y.Z, then flips the ~/.founderos/current symlink.
# A failed download NEVER touches the running version. After a successful swap we
# restart the service so the browser picks up the new build on next load.
#
# Usage:
#   bash scripts/install/vps-update-linux.sh
#   FOUNDEROS_BUNDLE_URL=https://.../founderos-server-v0.4.3.tar.gz bash scripts/install/vps-update-linux.sh
set -euo pipefail

APP_ID="aivaos"
RELEASES_REPO="${AIVAOS_RELEASES_REPO:-${FOUNDEROS_RELEASES_REPO:-Smartoptimize/aivaos-releases}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="${SCRIPT_DIR}/install-linux.sh"

log() { printf '%s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[[ -f "$INSTALLER" ]] || fail "install-linux.sh not found next to this script (${INSTALLER})."

resolve_latest_bundle_url() {
  # Only attempt when the caller has not pinned a bundle explicitly.
  [[ -n "${FOUNDEROS_BUNDLE_URL:-}" ]] && return 0
  command -v curl >/dev/null 2>&1 || return 0

  local api="https://api.github.com/repos/${RELEASES_REPO}/releases/latest"
  local auth=()
  # Private-repo release checks need a token; public feed does not. Honor either.
  local token="${FOUNDEROS_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
  [[ -n "$token" ]] && auth=(-H "Authorization: Bearer ${token}")

  local tag
  tag="$(curl -fsSL "${auth[@]}" "$api" 2>/dev/null \
    | grep -m1 '"tag_name"' \
    | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')" || return 0
  [[ -n "$tag" ]] || return 0

  local version="${tag#v}"
  export FOUNDEROS_BUNDLE_URL="https://github.com/${RELEASES_REPO}/releases/download/${tag}/aivaos-server-v${version}.tar.gz"
  log "Latest release: ${tag}"
}

log "Checking for the latest AIVAOS release..."
resolve_latest_bundle_url

if [[ -n "${FOUNDEROS_BUNDLE_URL:-}" ]]; then
  log "Installing bundle: ${FOUNDEROS_BUNDLE_URL}"
else
  log "Could not resolve a newer release automatically; re-running the pinned installer."
fi

# install-linux.sh ends by launching the app in the foreground; we only want the
# install + atomic swap, not a foreground run under a service box. Suppress the
# auto-launch and let systemd own the process.
FOUNDEROS_OPEN_BROWSER=0 FOUNDEROS_SKIP_LAUNCH=1 bash "$INSTALLER" || fail "Install step failed. Your previous version is untouched and still running."

if systemctl --user list-unit-files "${APP_ID}.service" >/dev/null 2>&1 \
   && systemctl --user cat "${APP_ID}.service" >/dev/null 2>&1; then
  log "Restarting the AIVAOS service to load the new build..."
  systemctl --user restart "${APP_ID}.service"
  log "Done. Reload the page in your browser to see the update."
else
  log "Update installed. No systemd service found — start it with vps-service-linux.sh, or run '${APP_ID}'."
fi

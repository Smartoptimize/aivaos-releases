#!/usr/bin/env bash
# AIVAOS Linux browser/localhost installer.
# Installs the localhost server bundle and opens AIVAOS in the browser.
# Downloads from the PUBLIC AivaOS release feed
# (github.com/Smartoptimize/aivaos-releases). Override with AIVAOS_BUNDLE_URL.
#
# This must NEVER resolve to any feed other than the AIVAOS one above. This file is
# published verbatim to the public release repo and read by clients, so it names no
# other product. See the private source repo for the full rationale.
#
# NOTE FOR MAINTAINERS: this resolves to the server bundle attached to the matching
# release. Publish `aivaos-server-v$VERSION.tar.gz` (+ SHA256SUMS) to that
# release for the download to succeed — until then the installer reports a clean error.
#
# INSTALL_DIR still defaults to ~/.founderos on purpose — the app's engine and hosting
# state already live there (`~/.founderos/engine`, `~/.founderos/hosting`). Moving it is
# a migration, not a rename, so it is deliberately left for a separate decision.
set -euo pipefail

APP_NAME="AIVAOS"
APP_ID="aivaos"
VERSION="0.4.2"
PORT="${PORT:-25808}"
AIVAOS_RELEASE_BASE="https://github.com/Smartoptimize/aivaos-releases/releases/download"
FOUNDEROS_BUNDLE_URL="${AIVAOS_BUNDLE_URL:-${FOUNDEROS_BUNDLE_URL:-${AIVAOS_RELEASE_BASE}/v${VERSION}/aivaos-server-v${VERSION}.tar.gz}}"
FOUNDEROS_CHECKSUM_URL="${FOUNDEROS_CHECKSUM_URL:-${FOUNDEROS_BUNDLE_URL%/*}/SHA256SUMS}"
INSTALL_DIR="${FOUNDEROS_INSTALL_DIR:-$HOME/.founderos}"
VERSION_DIR="${INSTALL_DIR}/v${VERSION}"
CURRENT_LINK="${INSTALL_DIR}/current"
LAUNCHER_DIR="${HOME}/.local/bin"
LAUNCHER_PATH="${LAUNCHER_DIR}/${APP_ID}"
DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/${APP_ID}-server.desktop"
BROWSER_URL="${FOUNDEROS_BROWSER_URL:-http://localhost:${PORT}}"
INSTALL_TMP_DIR=""

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

detect_platform() {
  [[ "$(uname -s)" == "Linux" ]] || fail "This installer is for Linux. Use install-macos.sh or install-windows.ps1 on other systems."

  case "$(uname -m)" in
    x86_64 | amd64 | aarch64 | arm64) ;;
    *) fail "Unsupported Linux CPU architecture: $(uname -m). Supported: x86_64 and arm64/aarch64." ;;
  esac

  if command -v getconf >/dev/null 2>&1 && getconf GNU_LIBC_VERSION >/dev/null 2>&1; then
    return
  fi

  if command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | head -n 1 | grep -qi 'glibc\|gnu libc'; then
    return
  fi

  fail "This localhost server bundle expects a glibc-based Linux distribution. Alpine/musl and other libc variants are not supported by this installer."
}

download_file() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --retry-delay 2 -o "$output" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$output" "$url"
  else
    fail "Missing curl or wget; install one of them and run this script again."
  fi
}

install_bun_if_missing() {
  if command -v bun >/dev/null 2>&1; then
    return
  fi

  need_command curl
  log "Bun was not found. Installing Bun from https://bun.sh/install ..."
  curl -fsSL https://bun.sh/install | bash
  export PATH="${HOME}/.bun/bin:${PATH}"

  command -v bun >/dev/null 2>&1 || fail "Bun installation finished, but bun is still not on PATH. Add ${HOME}/.bun/bin to PATH and rerun this script."
}

verify_checksum() {
  local bundle="$1"
  local checksum_file="$2"
  local artifact_name="$3"
  local expected

  need_command sha256sum
  expected="$(awk -v name="$artifact_name" '
    {
      file = $2
      sub(/^\*/, "", file)
      sub(/^\.\//, "", file)
      if (file == name) {
        print $1
        found = 1
        exit
      }
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$checksum_file" | tr -d '\r')" || fail "SHA256SUMS did not contain an entry for ${artifact_name}."
  [[ "$expected" =~ ^[A-Fa-f0-9]{64}$ ]] || fail "SHA256SUMS entry for ${artifact_name} did not contain a valid SHA256 hash."

  printf '%s  %s\n' "$expected" "$bundle" | sha256sum -c -
}

extract_bundle() {
  local bundle="$1"
  local extract_root="$2"
  local staging_dir="$3"
  local server_file
  local payload_root

  need_command tar
  mkdir -p "$extract_root" "$staging_dir"
  tar -xzf "$bundle" -C "$extract_root"

  server_file="$(find "$extract_root" -maxdepth 4 -type f -path '*/dist-server/server.mjs' -print -quit)"
  [[ -n "$server_file" ]] || fail "Bundle did not contain dist-server/server.mjs."

  payload_root="$(dirname "$(dirname "$server_file")")"
  (cd "$payload_root" && tar -cf - .) | (cd "$staging_dir" && tar -xf -)
}

create_launcher() {
  mkdir -p "$LAUNCHER_DIR"
  cat >"$LAUNCHER_PATH" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${FOUNDEROS_INSTALL_DIR:-$HOME/.founderos}/current"
PORT="${PORT:-25808}"
BROWSER_URL="${FOUNDEROS_BROWSER_URL:-http://localhost:${PORT}}"
BROWSER_DELAY="${FOUNDEROS_BROWSER_DELAY:-2}"

if [[ ! -x "${APP_ROOT}/start.sh" ]]; then
  printf 'AIVAOS server is not installed at %s\n' "$APP_ROOT" >&2
  exit 1
fi

if ! command -v bun >/dev/null 2>&1; then
  printf 'Bun is required but was not found on PATH. Install Bun from https://bun.sh and try again.\n' >&2
  exit 1
fi

cd "$APP_ROOT"
NODE_ENV="${NODE_ENV:-production}" IS_PACKAGED="${IS_PACKAGED:-true}" PORT="$PORT" ./start.sh "$@" &
server_pid=$!

cleanup() {
  if kill -0 "$server_pid" >/dev/null 2>&1; then
    kill "$server_pid" >/dev/null 2>&1 || true
  fi
}

trap cleanup INT TERM
sleep "$BROWSER_DELAY"

if [[ "${FOUNDEROS_OPEN_BROWSER:-1}" != "0" ]] && command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$BROWSER_URL" >/dev/null 2>&1 || true
fi

wait "$server_pid"
LAUNCHER
  chmod +x "$LAUNCHER_PATH"
}

create_desktop_entry() {
  mkdir -p "$DESKTOP_DIR"
  cat >"$DESKTOP_FILE" <<DESKTOP
[Desktop Entry]
Type=Application
Name=${APP_NAME} Server
Comment=Start ${APP_NAME} localhost server
Exec=${LAUNCHER_PATH}
Terminal=true
Categories=Development;Utility;
DESKTOP

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
}

install_bundle() {
  local tmp_dir
  local bundle_file
  local checksum_file
  local extract_root
  local staging_dir
  local artifact_name

  tmp_dir="$(mktemp -d)"
  INSTALL_TMP_DIR="$tmp_dir"
  trap 'rm -rf "$INSTALL_TMP_DIR"' EXIT

  artifact_name="${FOUNDEROS_BUNDLE_URL##*/}"
  bundle_file="${tmp_dir}/${artifact_name}"
  checksum_file="${tmp_dir}/SHA256SUMS"
  extract_root="${tmp_dir}/extract"
  staging_dir="${tmp_dir}/payload"

  log "Downloading ${APP_NAME} server bundle..."
  download_file "$FOUNDEROS_BUNDLE_URL" "$bundle_file"
  download_file "$FOUNDEROS_CHECKSUM_URL" "$checksum_file"
  verify_checksum "$bundle_file" "$checksum_file" "$artifact_name"

  log "Extracting bundle to ${VERSION_DIR}..."
  extract_bundle "$bundle_file" "$extract_root" "$staging_dir"

  mkdir -p "$INSTALL_DIR"
  rm -rf "${VERSION_DIR}.tmp"
  mv "$staging_dir" "${VERSION_DIR}.tmp"
  rm -rf "$VERSION_DIR"
  mv "${VERSION_DIR}.tmp" "$VERSION_DIR"
  ln -sfn "$VERSION_DIR" "$CURRENT_LINK"
}

main() {
  detect_platform
  install_bun_if_missing
  install_bundle
  create_launcher
  create_desktop_entry

  log "${APP_NAME} server ${VERSION} installed."
  log "Launcher: ${LAUNCHER_PATH}"
  if [[ ":${PATH}:" != *":${LAUNCHER_DIR}:"* ]]; then
    log "PATH note: add ${LAUNCHER_DIR} to PATH to run '${APP_ID}' from any terminal."
  fi

  # Headless/service installs (VPS update helper, systemd) only want the atomic
  # install + `current` symlink swap — not a foreground launch that would block.
  if [[ "${FOUNDEROS_SKIP_LAUNCH:-0}" == "1" || "${FOUNDEROS_SKIP_LAUNCH:-}" == "true" ]]; then
    log "Skipping launch (FOUNDEROS_SKIP_LAUNCH set)."
    return
  fi

  log "Opening ${BROWSER_URL}..."
  "$LAUNCHER_PATH"
}

main "$@"

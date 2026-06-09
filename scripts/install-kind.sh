#!/usr/bin/env bash
set -euo pipefail

tool_version="${TOOL_VERSION:-}"
version_file="/etc/vm-tool-versions.txt"

log() {
  printf '[install-kind] %s\n' "$*"
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log "must be run as root"
    exit 1
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) printf 'amd64' ;;
    aarch64 | arm64) printf 'arm64' ;;
    *)
      log "unsupported architecture: $(uname -m)"
      exit 1
      ;;
  esac
}

resolve_version() {
  if [ -n "$tool_version" ]; then
    case "$tool_version" in
      v*) printf '%s' "$tool_version" ;;
      *) printf 'v%s' "$tool_version" ;;
    esac
  else
    latest_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/kubernetes-sigs/kind/releases/latest)"
    basename "$latest_url"
  fi
}

install_kind() {
  arch="$(detect_arch)"
  release_tag="$(resolve_version)"
  url="https://github.com/kubernetes-sigs/kind/releases/download/${release_tag}/kind-linux-${arch}"

  log "installing kind $release_tag"
  curl -fsSL "$url" -o /usr/local/bin/kind
  chmod 0755 /usr/local/bin/kind
}

record_version() {
  resolved_version="$(kind --version)"
  printf 'kind: %s\n' "$resolved_version" >> "$version_file"
  log "recorded $resolved_version"
}

require_root
install_kind
record_version

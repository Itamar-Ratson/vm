#!/usr/bin/env bash
set -euo pipefail

tool_version="${TOOL_VERSION:-}"
version_file="/etc/vm-tool-versions.txt"

log() {
  printf '[install-helm] %s\n' "$*"
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log "must be run as root"
    exit 1
  fi
}

normalize_version() {
  case "$tool_version" in
    "" ) return 1 ;;
    v*) printf '%s' "$tool_version" ;;
    *) printf 'v%s' "$tool_version" ;;
  esac
}

install_helm() {
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o "$tmp_dir/get_helm.sh"
  chmod 0700 "$tmp_dir/get_helm.sh"

  if [ -n "$tool_version" ]; then
    version="$(normalize_version)"
    log "installing Helm $version"
    "$tmp_dir/get_helm.sh" --version "$version"
  else
    log "installing latest Helm"
    "$tmp_dir/get_helm.sh"
  fi
}

record_version() {
  resolved_version="$(helm version --short)"
  printf 'helm: %s\n' "$resolved_version" >> "$version_file"
  log "recorded $resolved_version"
}

require_root
install_helm
record_version

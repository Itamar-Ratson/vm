#!/usr/bin/env bash
set -euo pipefail

tool_version="${TOOL_VERSION:-}"
version_file="/etc/vm-tool-versions.txt"

log() {
  printf '[install-git] %s\n' "$*"
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log "must be run as root"
    exit 1
  fi
}

install_git() {
  export DEBIAN_FRONTEND=noninteractive

  apt-get update
  if [ -n "$tool_version" ]; then
    log "installing Git apt version $tool_version"
    apt-get install -y "git=$tool_version"
  else
    log "installing latest Git"
    apt-get install -y git
  fi
}

record_version() {
  resolved_version="$(git --version)"
  printf 'git: %s\n' "$resolved_version" >> "$version_file"
  log "recorded $resolved_version"
}

require_root
install_git
record_version

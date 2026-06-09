#!/usr/bin/env bash
set -euo pipefail

tool_version="${TOOL_VERSION:-}"
version_file="/etc/vm-tool-versions.txt"

log() {
  printf '[install-jq] %s\n' "$*"
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log "must be run as root"
    exit 1
  fi
}

install_jq() {
  export DEBIAN_FRONTEND=noninteractive

  apt-get update
  if [ -n "$tool_version" ]; then
    log "installing jq apt version $tool_version"
    apt-get install -y "jq=$tool_version"
  else
    log "installing latest jq"
    apt-get install -y jq
  fi
}

record_version() {
  resolved_version="$(jq --version)"
  printf 'jq: %s\n' "$resolved_version" >> "$version_file"
  log "recorded $resolved_version"
}

require_root
install_jq
record_version

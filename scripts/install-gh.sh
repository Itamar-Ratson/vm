#!/usr/bin/env bash
set -euo pipefail

tool_version="${TOOL_VERSION:-}"
version_file="/etc/vm-tool-versions.txt"

log() {
  printf '[install-gh] %s\n' "$*"
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log "must be run as root"
    exit 1
  fi
}

configure_apt_repo() {
  export DEBIAN_FRONTEND=noninteractive

  apt-get update
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
  chmod 0644 /etc/apt/keyrings/githubcli-archive-keyring.gpg
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' "$(dpkg --print-architecture)" > /etc/apt/sources.list.d/github-cli.list
  apt-get update
}

package_version_for_pin() {
  apt-cache madison gh | awk -v pin="$tool_version" '$3 == pin || index($3, pin "-") == 1 { print $3; exit }'
}

install_gh() {
  if [ -n "$tool_version" ]; then
    package_version="$(package_version_for_pin)"
    if [ -z "$package_version" ]; then
      log "gh version $tool_version was not found in the GitHub CLI apt repo"
      exit 1
    fi
    log "installing gh apt version $package_version"
    apt-get install -y "gh=$package_version"
  else
    log "installing latest gh"
    apt-get install -y gh
  fi
}

record_version() {
  resolved_version="$(gh --version | head -n 1)"
  printf 'gh: %s\n' "$resolved_version" >> "$version_file"
  log "recorded $resolved_version"
}

require_root
configure_apt_repo
install_gh
record_version

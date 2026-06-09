#!/usr/bin/env bash
set -euo pipefail

tool_version="${TOOL_VERSION:-}"
version_file="/etc/vm-tool-versions.txt"

log() {
  printf '[install-terraform] %s\n' "$*"
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
  curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg
  chmod 0644 /etc/apt/keyrings/hashicorp-archive-keyring.gpg

  . /etc/os-release
  printf 'deb [signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com %s main\n' "$VERSION_CODENAME" > /etc/apt/sources.list.d/hashicorp.list
  apt-get update
}

package_version_for_pin() {
  apt-cache madison terraform | awk -v pin="$tool_version" '$3 == pin || index($3, pin "-") == 1 { print $3; exit }'
}

install_terraform() {
  if [ -n "$tool_version" ]; then
    package_version="$(package_version_for_pin)"
    if [ -z "$package_version" ]; then
      log "terraform version $tool_version was not found in the HashiCorp apt repo"
      exit 1
    fi
    log "installing Terraform apt version $package_version"
    apt-get install -y "terraform=$package_version"
  else
    log "installing latest Terraform"
    apt-get install -y terraform
  fi
}

record_version() {
  resolved_version="$(terraform version -json | awk -F'"' '/terraform_version/ {print $4; exit}')"
  printf 'terraform: %s\n' "$resolved_version" >> "$version_file"
  log "recorded $resolved_version"
}

require_root
configure_apt_repo
install_terraform
record_version

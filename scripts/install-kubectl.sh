#!/usr/bin/env bash
set -euo pipefail

tool_version="${TOOL_VERSION:-}"
version_file="/etc/vm-tool-versions.txt"

log() {
  printf '[install-kubectl] %s\n' "$*"
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    log "must be run as root"
    exit 1
  fi
}

version_without_v() {
  printf '%s' "${1#v}"
}

minor_channel_for() {
  version="$(version_without_v "$1")"
  major="$(printf '%s' "$version" | cut -d. -f1)"
  minor="$(printf '%s' "$version" | cut -d. -f2)"
  printf 'v%s.%s' "$major" "$minor"
}

resolve_latest_stable() {
  curl -fsSL https://dl.k8s.io/release/stable.txt
}

configure_apt_repo() {
  export DEBIAN_FRONTEND=noninteractive

  apt-get update
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings

  if [ -n "$tool_version" ]; then
    channel="$(minor_channel_for "$tool_version")"
  else
    channel="$(minor_channel_for "$(resolve_latest_stable)")"
  fi

  log "configuring Kubernetes apt repo stable $channel"
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/${channel}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  chmod 0644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  printf 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/%s/deb/ /\n' "$channel" > /etc/apt/sources.list.d/kubernetes.list
  apt-get update
}

install_kubectl() {
  if [ -n "$tool_version" ]; then
    package_version="$(version_without_v "$tool_version")-1.1"
    log "installing kubectl apt version $package_version"
    apt-get install -y "kubectl=$package_version"
  else
    log "installing latest kubectl"
    apt-get install -y kubectl
  fi
}

record_version() {
  resolved_version="$(kubectl version --client=true --output=yaml | awk '/gitVersion:/ {print $2; exit}')"
  printf 'kubectl: %s\n' "$resolved_version" >> "$version_file"
  log "recorded $resolved_version"
}

require_root
configure_apt_repo
install_kubectl
record_version

#!/usr/bin/env bash
set -euo pipefail

tool_version="${TOOL_VERSION:-}"
version_file="/etc/vm-tool-versions.txt"

log() {
  printf '[install-docker] %s\n' "$*"
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
  apt-get install -y ca-certificates curl

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  . /etc/os-release
  arch="$(dpkg --print-architecture)"
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu %s stable\n' "$arch" "$VERSION_CODENAME" > /etc/apt/sources.list.d/docker.list

  apt-get update
}

install_docker() {
  if [ -n "$tool_version" ]; then
    log "installing Docker apt version $tool_version"
    apt-get install -y \
      "docker-ce=$tool_version" \
      "docker-ce-cli=$tool_version" \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin
  else
    log "installing latest Docker"
    apt-get install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin
  fi
}

configure_docker_group() {
  groupadd -f docker

  if id dev >/dev/null 2>&1; then
    usermod -aG docker dev
  else
    log "user dev does not exist; skipping docker group membership"
  fi
}

start_docker_if_systemd_available() {
  if [ -d /run/systemd/system ]; then
    systemctl enable --now docker
  else
    log "systemd is not running; skipping docker service enable/start"
  fi
}

record_version() {
  resolved_version="$(docker --version)"
  printf 'docker: %s\n' "$resolved_version" >> "$version_file"
  log "recorded $resolved_version"
}

require_root
configure_apt_repo
install_docker
configure_docker_group
start_docker_if_systemd_available
record_version

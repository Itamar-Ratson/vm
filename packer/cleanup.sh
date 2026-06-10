#!/usr/bin/env bash
set -euo pipefail

required_env=(
  SOURCE_CLOUD_IMAGE_URL
  SOURCE_CLOUD_IMAGE_SHA256
  BUILD_TIMESTAMP_RFC3339
  GIT_SHORT_SHA
  TOOLS
  TOOL_VERSIONS
)

if [ "$(id -u)" -ne 0 ]; then
  printf 'packer/cleanup.sh must run as root\n' >&2
  exit 1
fi

for name in "${required_env[@]}"; do
  if [ -z "${!name+x}" ]; then
    printf 'required environment variable %s is not set\n' "$name" >&2
    exit 1
  fi
done

cat >/etc/vm-build-info.txt <<EOF
source_cloud_image_url=${SOURCE_CLOUD_IMAGE_URL}
source_cloud_image_sha256=${SOURCE_CLOUD_IMAGE_SHA256}
build_timestamp=${BUILD_TIMESTAMP_RFC3339}
git_sha=${GIT_SHORT_SHA}
tools=${TOOLS}
tool_versions=${TOOL_VERSIONS}
EOF

wipe_dir() {
  local dir="$1"

  mkdir -p "$dir"
  find "$dir" -mindepth 1 -exec rm -rf -- {} +
}

apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/*.bin
wipe_dir /var/cache/apt/archives

wipe_dir /tmp
wipe_dir /var/tmp
wipe_dir /var/log

if getent passwd builder >/dev/null; then
  userdel -f -r builder 2>/dev/null || true
fi
rm -rf /home/builder /var/mail/builder

wipe_dir /var/lib/cloud
rm -f /var/log/cloud-init /var/log/cloud-init.log /var/log/cloud-init-output.log

: >/etc/machine-id
mkdir -p /var/lib/dbus
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

rm -f /etc/ssh/ssh_host_*

if ! fstrim -av; then
  printf 'fstrim is unavailable in this environment; continuing\n' >&2
fi

if command -v systemd-run >/dev/null && [ -d /run/systemd/system ]; then
  systemd-run --on-active=5s /sbin/shutdown -P now >/dev/null
fi

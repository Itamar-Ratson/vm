#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
build_dir="$script_dir/.build"
cache_dir="$script_dir/cache"
output_dir="$script_dir/output"
seed_template="$script_dir/seed/user-data.tpl"
seed_user_data="$script_dir/seed/user-data"
source_cloud_image_url="${SOURCE_CLOUD_IMAGE_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"
source_image_path="$cache_dir/$(basename "$source_cloud_image_url")"

cleanup() {
  rm -rf "$build_dir"
  rm -f "$seed_user_data"
}

trap cleanup EXIT

need_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'required command not found: %s\n' "$command_name" >&2
    exit 1
  fi
}

need_command curl
need_command git
need_command packer
need_command qemu-img
need_command sed
need_command sha256sum
need_command ssh-keygen

rm -rf "$build_dir"
mkdir -p "$build_dir" "$cache_dir" "$output_dir"
rm -rf "$output_dir/qemu"
rm -f "$output_dir/devops-sandbox-base.qcow2" "$output_dir/devops-sandbox-base.qcow2.tmp"

ssh-keygen -q -t ed25519 -N "" -f "$build_dir/builder_id"

escaped_pubkey="$(sed 's/[&|\\]/\\&/g' "$build_dir/builder_id.pub")"
sed "s|@SSH_PUBKEY@|$escaped_pubkey|" "$seed_template" >"$seed_user_data"

if [ ! -f "$source_image_path" ]; then
  curl -fL --retry 3 --output "$source_image_path" "$source_cloud_image_url"
fi

source_cloud_image_sha256="$(sha256sum "$source_image_path" | awk '{print $1}')"
build_timestamp_rfc3339="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
git_short_sha="$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"

packer init "$script_dir/devops-sandbox.pkr.hcl"
packer build \
  -var "source_cloud_image_url=$source_cloud_image_url" \
  -var "source_image_path=$source_image_path" \
  -var "source_cloud_image_sha256=$source_cloud_image_sha256" \
  -var "ssh_private_key_file=$build_dir/builder_id" \
  -var "build_timestamp_rfc3339=$build_timestamp_rfc3339" \
  -var "git_short_sha=$git_short_sha" \
  "$@" \
  "$script_dir/devops-sandbox.pkr.hcl"

test -f "$output_dir/devops-sandbox-base.qcow2"

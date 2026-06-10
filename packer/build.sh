#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
build_dir="$script_dir/.build"
cache_dir="$script_dir/cache"
seed_user_data="$build_dir/seed/user-data"
source_cloud_image_url="${SOURCE_CLOUD_IMAGE_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"
source_cloud_image_file="$cache_dir/ubuntu-noble-server-cloudimg-amd64.img"

cleanup() {
  rm -rf "$build_dir"
}
trap cleanup EXIT

mkdir -p "$build_dir/seed" "$cache_dir" "$script_dir/output"

if ! command -v packer >/dev/null; then
  printf 'packer is required; install Packer and retry\n' >&2
  exit 1
fi

if ! command -v ssh-keygen >/dev/null; then
  printf 'ssh-keygen is required to create the ephemeral builder key\n' >&2
  exit 1
fi

if [ ! -s "$source_cloud_image_file" ]; then
  if ! command -v curl >/dev/null; then
    printf 'curl is required to download %s\n' "$source_cloud_image_url" >&2
    exit 1
  fi

  curl -fL --retry 3 --output "$source_cloud_image_file.tmp" "$source_cloud_image_url"
  mv "$source_cloud_image_file.tmp" "$source_cloud_image_file"
fi

source_cloud_image_sha256="$(sha256sum "$source_cloud_image_file" | awk '{print $1}')"
git_short_sha="$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"

ssh-keygen -t ed25519 -N "" -f "$build_dir/builder_id" >/dev/null
escaped_pubkey="$(sed 's/[&|\\]/\\&/g' "$build_dir/builder_id.pub")"
sed "s|@SSH_PUBKEY@|$escaped_pubkey|" \
  "$script_dir/seed/user-data.tpl" >"$seed_user_data"
cp "$script_dir/seed/meta-data" "$build_dir/seed/meta-data"

packer init "$script_dir/devops-sandbox.pkr.hcl"
packer build -force \
  -var "ssh_private_key_file=$build_dir/builder_id" \
  -var "source_cloud_image_file=$source_cloud_image_file" \
  -var "source_cloud_image_url=$source_cloud_image_url" \
  -var "source_cloud_image_sha256=$source_cloud_image_sha256" \
  -var "git_sha=$git_short_sha" \
  "$script_dir/devops-sandbox.pkr.hcl"

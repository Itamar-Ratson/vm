#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

build_dir="packer/.build"
seed_dir="$build_dir/seed"
key_path="$build_dir/builder_id"
source_cloud_image_url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
source_image_path="packer/cache/noble-server-cloudimg-amd64.img"

cleanup() {
  rm -rf "$build_dir"
}
trap cleanup EXIT

mkdir -p "$seed_dir" "packer/cache" "packer/output"

if [ ! -f "$source_image_path" ]; then
  curl -fsSL "$source_cloud_image_url" -o "$source_image_path"
fi

source_cloud_image_sha256="$(sha256sum "$source_image_path" | awk '{print $1}')"
build_timestamp_rfc3339="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
git_short_sha="$(git rev-parse --short HEAD 2>/dev/null || printf 'unknown')"

ssh-keygen -t ed25519 -N "" -f "$key_path" -C "packer-builder"
ssh_pubkey="$(cat "${key_path}.pub")"
sed "s|@SSH_PUBKEY@|${ssh_pubkey}|" packer/seed/user-data.tpl >"$seed_dir/user-data"
cp packer/seed/meta-data "$seed_dir/meta-data"

packer build \
  -var "iso_url=${source_image_path}" \
  -var "ssh_private_key_file=${key_path}" \
  -var "seed_meta_data_path=${seed_dir}/meta-data" \
  -var "seed_user_data_path=${seed_dir}/user-data" \
  -var "source_cloud_image_url=${source_cloud_image_url}" \
  -var "source_cloud_image_sha256=${source_cloud_image_sha256}" \
  -var "build_timestamp_rfc3339=${build_timestamp_rfc3339}" \
  -var "git_short_sha=${git_short_sha}" \
  packer/devops-sandbox.pkr.hcl

packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "source_cloud_image_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "source_image_path" {
  type = string
}

variable "source_cloud_image_sha256" {
  type = string
}

variable "ssh_private_key_file" {
  type = string
}

variable "build_timestamp_rfc3339" {
  type = string
}

variable "git_short_sha" {
  type = string
}

variable "tools" {
  type    = list(string)
  default = ["docker", "kind", "helm", "kubectl", "terraform", "git", "gh", "jq", "yq"]
}

variable "tool_versions" {
  type    = map(string)
  default = {}
}

locals {
  output_dir        = "${path.root}/output"
  transient_out_dir = "${local.output_dir}/qemu"
  final_image       = "${local.output_dir}/devops-sandbox-base.qcow2"
  scripts_dir       = "${path.root}/../scripts"
  tools_csv         = join(",", var.tools)
  tool_versions_csv = join(",", [for name, version in var.tool_versions : "${name}=${version}"])
}

source "qemu" "devops_sandbox" {
  accelerator      = "kvm"
  boot_wait        = "5s"
  cd_files         = ["${path.root}/seed/meta-data", "${path.root}/seed/user-data"]
  cd_label         = "cidata"
  cpus             = 6
  disk_compression = false
  disk_image       = true
  disk_size        = "12G"
  format           = "qcow2"
  headless         = true
  iso_checksum     = "none"
  iso_url          = var.source_image_path
  memory           = 6144
  net_device       = "virtio-net"
  output_directory = local.transient_out_dir
  shutdown_command = "sudo shutdown -P now"
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = "45m"
  ssh_username         = "builder"
  vm_name              = "devops-sandbox-base-uncompressed.qcow2"

  qemuargs = [
    ["-cpu", "host"],
    ["-machine", "type=q35,accel=kvm"],
    ["-serial", "mon:stdio"],
  ]
}

build {
  name    = "devops-sandbox-base"
  sources = ["source.qemu.devops_sandbox"]

  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "sudo cloud-init status --wait || { sudo cloud-init status --long; exit 1; }",
    ]
  }

  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline = [
      "set -euo pipefail",
      "sudo apt-get update",
      "sudo -E apt-get install -y ubuntu-desktop-minimal spice-vdagent firefox",
    ]
  }

  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "sudo install -d -m 0755 /etc/gdm3",
      "printf '%s\\n' '[daemon]' 'AutomaticLoginEnable=true' 'AutomaticLogin=dev' | sudo tee /etc/gdm3/custom.conf >/dev/null",
      "if ! id dev >/dev/null 2>&1; then sudo useradd --create-home --shell /bin/bash --groups sudo,adm dev; fi",
      "sudo passwd --lock dev",
      "sudo install -d -m 0700 -o dev -g dev /home/dev/.ssh",
      "printf '%s\\n' 'dev ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/90-dev-nopasswd >/dev/null",
      "sudo chmod 0440 /etc/sudoers.d/90-dev-nopasswd",
    ]
  }

  provisioner "file" {
    source      = local.scripts_dir
    destination = "/tmp/install-scripts"
  }

  provisioner "shell" {
    inline = concat(
      [
        "set -euo pipefail",
        "sudo install -d -m 0755 /usr/local/sbin",
        "sudo cp /tmp/install-scripts/install-*.sh /usr/local/sbin/",
        "sudo chmod 0755 /usr/local/sbin/install-*.sh",
      ],
      [
        for tool in var.tools : "sudo env TOOL_VERSION='${lookup(var.tool_versions, tool, "")}' /usr/local/sbin/install-${tool}.sh"
      ],
    )
  }

  provisioner "file" {
    source      = "${path.root}/cleanup.sh"
    destination = "/tmp/cleanup.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "SOURCE_CLOUD_IMAGE_URL=${var.source_cloud_image_url}",
      "SOURCE_CLOUD_IMAGE_SHA256=${var.source_cloud_image_sha256}",
      "BUILD_TIMESTAMP_RFC3339=${var.build_timestamp_rfc3339}",
      "GIT_SHORT_SHA=${var.git_short_sha}",
      "TOOLS=${local.tools_csv}",
      "TOOL_VERSIONS=${local.tool_versions_csv}",
    ]
    inline = [
      "set -euo pipefail",
      "sudo chmod 0755 /tmp/cleanup.sh",
      "sudo -E /tmp/cleanup.sh",
    ]
  }

  post-processor "shell-local" {
    inline = [
      "set -euo pipefail",
      "artifact_path=\"${local.transient_out_dir}/devops-sandbox-base-uncompressed.qcow2\"",
      "test -f \"$artifact_path\"",
      "tmp_image=\"${local.final_image}.tmp\"",
      "qemu-img convert -c -O qcow2 \"$artifact_path\" \"$tmp_image\"",
      "rm -rf \"${local.transient_out_dir}\"",
      "mv \"$tmp_image\" \"${local.final_image}\"",
    ]
  }
}

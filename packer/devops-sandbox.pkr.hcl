packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "source_cloud_image_file" {
  type    = string
  default = "cache/ubuntu-noble-server-cloudimg-amd64.img"
}

variable "source_cloud_image_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "source_cloud_image_sha256" {
  type    = string
  default = "unknown"
}

variable "ssh_private_key_file" {
  type    = string
  default = ".build/builder_id"
}

variable "git_sha" {
  type    = string
  default = "unknown"
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
  build_timestamp = timestamp()
  tool_versions   = join(",", [for name, version in var.tool_versions : "${name}=${version}"])
}

source "qemu" "ubuntu_noble" {
  iso_url      = var.source_cloud_image_file
  iso_checksum = "none"
  disk_image   = true

  output_directory = "${path.root}/output"
  vm_name          = "devops-sandbox-base.qcow2"
  format           = "qcow2"
  disk_size        = "12G"
  disk_compression = true

  accelerator = "kvm"
  headless    = true
  memory      = 6144
  cpus        = 6

  disk_interface = "virtio"
  net_device     = "virtio-net"

  cd_files = [
    "${path.root}/.build/seed/user-data",
    "${path.root}/.build/seed/meta-data",
  ]
  cd_label = "cidata"

  ssh_username         = "builder"
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = "30m"

  shutdown_command = "sudo shutdown -P now"

  qemuargs = [["-device", "virtio-rng-pci"]]
}

build {
  sources = ["source.qemu.ubuntu_noble"]

  provisioner "shell" {
    inline = [
      "cloud-init status --wait",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-desktop-minimal spice-vdagent firefox qemu-guest-agent cloud-guest-utils",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo useradd --create-home --shell /bin/bash --groups sudo,adm dev",
      "sudo passwd --lock dev",
      "sudo install -d -m 0700 -o dev -g dev /home/dev/.ssh",
      "printf 'dev ALL=(ALL) NOPASSWD:ALL\\n' | sudo tee /etc/sudoers.d/90-dev-nopasswd >/dev/null",
      "sudo chmod 0440 /etc/sudoers.d/90-dev-nopasswd",
      "sudo mkdir -p /etc/gdm3",
      "printf '[daemon]\\nAutomaticLoginEnable=true\\nAutomaticLogin=dev\\n' | sudo tee /etc/gdm3/custom.conf >/dev/null",
    ]
  }

  provisioner "file" {
    source      = "${path.root}/../scripts/"
    destination = "/tmp/install-scripts"
  }

  provisioner "shell" {
    inline = concat(
      [
        "sudo chmod +x /tmp/install-scripts/install-*.sh",
      ],
      [for tool in var.tools : "sudo env TOOL_VERSION='${lookup(var.tool_versions, tool, "")}' /tmp/install-scripts/install-${tool}.sh"],
    )
  }

  provisioner "file" {
    source      = "${path.root}/cleanup.sh"
    destination = "/tmp/packer-cleanup.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "SOURCE_CLOUD_IMAGE_URL=${var.source_cloud_image_url}",
      "SOURCE_CLOUD_IMAGE_SHA256=${var.source_cloud_image_sha256}",
      "BUILD_TIMESTAMP_RFC3339=${local.build_timestamp}",
      "GIT_SHORT_SHA=${var.git_sha}",
      "TOOLS=${join(",", var.tools)}",
      "TOOL_VERSIONS=${local.tool_versions}",
    ]

    inline = [
      "sudo --preserve-env=SOURCE_CLOUD_IMAGE_URL,SOURCE_CLOUD_IMAGE_SHA256,BUILD_TIMESTAMP_RFC3339,GIT_SHORT_SHA,TOOLS,TOOL_VERSIONS bash /tmp/packer-cleanup.sh",
    ]
  }

  post-processor "shell-local" {
    inline = [
      "qemu-img convert -c -O qcow2 '${path.root}/output/devops-sandbox-base.qcow2' '${path.root}/output/devops-sandbox-base.qcow2.compressed'",
      "mv '${path.root}/output/devops-sandbox-base.qcow2.compressed' '${path.root}/output/devops-sandbox-base.qcow2'",
    ]
  }
}

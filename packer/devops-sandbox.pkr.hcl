packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "iso_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "ssh_private_key_file" {
  type    = string
  default = ""
}

variable "seed_meta_data_path" {
  type    = string
  default = "packer/seed/meta-data"
}

variable "seed_user_data_path" {
  type    = string
  default = "packer/seed/user-data.tpl"
}

variable "source_cloud_image_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "source_cloud_image_sha256" {
  type    = string
  default = "unknown"
}

variable "build_timestamp_rfc3339" {
  type    = string
  default = "unknown"
}

variable "git_short_sha" {
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
  tools_csv         = join(",", var.tools)
  tool_versions_csv = join(",", [for name, version in var.tool_versions : "${name}=${version}"])
}

source "qemu" "devops_sandbox" {
  iso_url          = var.iso_url
  iso_checksum     = "none"
  disk_image       = true
  output_directory = "packer/output"
  vm_name          = "devops-sandbox-base.qcow2"
  format           = "qcow2"

  accelerator = "kvm"
  headless    = true
  memory      = 6144
  cpus        = 6
  disk_size   = "12G"

  cd_files = [
    var.seed_meta_data_path,
    var.seed_user_data_path,
  ]
  cd_label = "cidata"

  ssh_username         = "builder"
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = "30m"

  shutdown_command = "sudo shutdown -P now"

  qemuargs = [
    ["-machine", "type=q35,accel=kvm"],
    ["-device", "virtio-net-pci,netdev=user.0"],
    ["-device", "virtio-rng-pci"],
    ["-vga", "qxl"],
    ["-spice", "port=5930,disable-ticketing=on"],
  ]
}

build {
  sources = ["source.qemu.devops_sandbox"]

  provisioner "shell" {
    inline = [
      "cloud-init status --wait",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-desktop-minimal spice-vdagent firefox",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo install -d -m 0755 /etc/gdm3",
      "printf '[daemon]\\nAutomaticLoginEnable=true\\nAutomaticLogin=dev\\n' | sudo tee /etc/gdm3/custom.conf >/dev/null",
    ]
  }

  provisioner "shell" {
    inline = [
      "if ! id -u dev >/dev/null 2>&1; then sudo useradd --create-home --shell /bin/bash --groups sudo,adm dev; fi",
      "sudo passwd -l dev",
      "echo 'dev ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/90-dev-nopasswd >/dev/null",
      "sudo chmod 0440 /etc/sudoers.d/90-dev-nopasswd",
      "sudo install -d -m 0700 -o dev -g dev /home/dev/.ssh",
    ]
  }

  provisioner "file" {
    source      = "scripts/"
    destination = "/tmp/install-scripts"
  }

  provisioner "shell" {
    inline = [
      "sudo install -d -m 0755 /usr/local/sbin",
      "sudo find /tmp/install-scripts -maxdepth 1 -name 'install-*.sh' -exec install -m 0755 {} /usr/local/sbin/ \\;",
    ]
  }

  dynamic "provisioner" {
    for_each = var.tools
    labels   = ["shell"]

    content {
      environment_vars = [
        "TOOL_VERSION=${lookup(var.tool_versions, provisioner.value, "")}",
      ]
      inline = [
        "sudo --preserve-env=TOOL_VERSION /usr/local/sbin/install-${provisioner.value}.sh",
      ]
    }
  }

  provisioner "file" {
    source      = "packer/cleanup.sh"
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
      "sudo --preserve-env=SOURCE_CLOUD_IMAGE_URL,SOURCE_CLOUD_IMAGE_SHA256,BUILD_TIMESTAMP_RFC3339,GIT_SHORT_SHA,TOOLS,TOOL_VERSIONS bash /tmp/cleanup.sh",
    ]
  }

  post-processor "shell-local" {
    inline = [
      "tmp='packer/output/devops-sandbox-base.qcow2.compressed'",
      "qemu-img convert -c -O qcow2 packer/output/devops-sandbox-base.qcow2 \"$tmp\"",
      "mv \"$tmp\" packer/output/devops-sandbox-base.qcow2",
    ]
  }
}

variable "vm_name" {
  description = "Name for the libvirt domain and related volumes."
  type        = string
  default     = "devops-sandbox"
}

variable "vm_vcpus" {
  description = "Number of virtual CPUs assigned to the VM."
  type        = number
  default     = 6
}

variable "vm_memory_mib" {
  description = "Memory assigned to the VM, in MiB."
  type        = number
  default     = 8192
}

variable "vm_disk_gb" {
  description = "Maximum size of the thin-provisioned qcow2 root disk, in GiB."
  type        = number
  default     = 20
}

variable "username" {
  description = "User created inside the VM."
  type        = string
  default     = "dev"
}

variable "ssh_pubkey_path" {
  description = "Path to the SSH public key injected into the VM. When unset, Terraform tries ~/.ssh/id_ed25519.pub and then ~/.ssh/id_rsa.pub."
  type        = string
  default     = null
}

variable "ubuntu_image_url" {
  description = "Ubuntu 24.04 cloud image URL used as the root disk backing image."
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "tools" {
  description = "Tool catalog entries installed during cloud-init, in order."
  type        = list(string)
  default     = ["docker", "kind", "helm", "kubectl", "terraform", "git", "gh", "jq", "yq"]
}

variable "tool_versions" {
  description = "Optional per-tool version pins. Missing or empty values install the latest available version."
  type        = map(string)
  default     = {}
}

locals {
  id_ed25519_pubkey_path = pathexpand("~/.ssh/id_ed25519.pub")
  id_rsa_pubkey_path     = pathexpand("~/.ssh/id_rsa.pub")

  detected_ssh_pubkey_path = (
    fileexists(local.id_ed25519_pubkey_path) ? local.id_ed25519_pubkey_path :
    fileexists(local.id_rsa_pubkey_path) ? local.id_rsa_pubkey_path :
    null
  )

  effective_ssh_pubkey_path = (
    var.ssh_pubkey_path != null && trimspace(var.ssh_pubkey_path) != "" ?
    pathexpand(var.ssh_pubkey_path) :
    local.detected_ssh_pubkey_path
  )

  ssh_pubkey_exists      = local.effective_ssh_pubkey_path != null && fileexists(local.effective_ssh_pubkey_path)
  ssh_public_key         = local.ssh_pubkey_exists ? trimspace(file(local.effective_ssh_pubkey_path)) : ""
  ssh_private_key_path   = local.ssh_pubkey_exists ? regexreplace(local.effective_ssh_pubkey_path, "\\.pub$", "") : null
  ssh_private_key_exists = local.ssh_private_key_path != null && fileexists(local.ssh_private_key_path)
  ssh_private_key        = local.ssh_private_key_exists ? file(local.ssh_private_key_path) : null
}

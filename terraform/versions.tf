terraform {
  required_version = ">= 1.5.0"

  required_providers {
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }

    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

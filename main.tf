resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-noble-server-cloudimg-amd64.qcow2"
  pool = "default"

  create = {
    content = {
      url = var.ubuntu_image_url
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }

  depends_on = [terraform_data.ssh_pubkey_check]
}

resource "libvirt_volume" "root" {
  name     = "${var.vm_name}-root.qcow2"
  pool     = "default"
  capacity = var.vm_disk_gb * 1024 * 1024 * 1024

  backing_store = {
    path = libvirt_volume.ubuntu_base.path
    format = {
      type = "qcow2"
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_volume" "cloudinit_iso" {
  name = "${var.vm_name}-cloudinit.iso"
  pool = "default"

  create = {
    content = {
      url = libvirt_cloudinit_disk.user_data.path
    }
  }
}

resource "libvirt_domain" "vm" {
  name        = var.vm_name
  type        = "kvm"
  memory      = var.vm_memory_mib
  memory_unit = "MiB"
  vcpu        = var.vm_vcpus
  running     = true

  os = {
    type    = "hvm"
    arch    = "x86_64"
    machine = "q35"
  }

  features = {
    acpi = true
  }

  sec_label = [
    {
      type  = "none"
      model = "apparmor"
    }
  ]

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_volume.root.pool
            volume = libvirt_volume.root.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_volume.cloudinit_iso.pool
            volume = libvirt_volume.cloudinit_iso.name
          }
        }
        target = {
          dev = "sdb"
          bus = "sata"
        }
      },
    ]

    interfaces = [
      {
        type = "network"
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "default"
          }
        }
        wait_for_ip = {
          timeout = 900
          source  = "lease"
        }
      },
    ]

    graphics = [
      {
        spice = {
          listen    = "127.0.0.1"
          auto_port = true
        }
      },
    ]

    videos = [
      {
        model = {
          type = "qxl"
        }
      },
    ]

    consoles = [
      {
        type = "pty"
        target = {
          type = "serial"
          port = 0
        }
      },
    ]

    channels = [
      {
        type = "spicevmc"
        source = {
          spice_vmc = true
        }
        target = {
          virt_io = {
            name = "com.redhat.spice.0"
          }
        }
      },
    ]
  }
}

data "libvirt_domain_interface_addresses" "vm" {
  domain = libvirt_domain.vm.name
  source = "lease"
}

resource "null_resource" "cloud_init_ready" {
  triggers = {
    domain_id      = libvirt_domain.vm.id
    cloudinit_id   = libvirt_volume.cloudinit_iso.id
    root_volume_id = libvirt_volume.root.id
  }

  connection {
    type        = "ssh"
    host        = data.libvirt_domain_interface_addresses.vm.interfaces[0].addrs[0].addr
    user        = var.username
    private_key = local.ssh_private_key
    agent       = true
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
    ]
  }
}

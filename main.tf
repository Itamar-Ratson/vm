resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-noble-server-cloudimg-amd64.qcow2"
  pool   = "default"
  source = var.ubuntu_image_url
  format = "qcow2"

  depends_on = [terraform_data.ssh_pubkey_check]
}

resource "libvirt_volume" "root" {
  name           = "${var.vm_name}-root.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = var.vm_disk_gb * 1024 * 1024 * 1024
  format         = "qcow2"
}

resource "libvirt_domain" "vm" {
  name   = var.vm_name
  memory = var.vm_memory_mib
  vcpu   = var.vm_vcpus

  cloudinit = libvirt_cloudinit_disk.user_data.id

  disk {
    volume_id = libvirt_volume.root.id
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  video {
    type = "qxl"
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}

resource "null_resource" "cloud_init_ready" {
  triggers = {
    domain_id      = libvirt_domain.vm.id
    cloudinit_id   = libvirt_cloudinit_disk.user_data.id
    root_volume_id = libvirt_volume.root.id
  }

  connection {
    type        = "ssh"
    host        = libvirt_domain.vm.network_interface[0].addresses[0]
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

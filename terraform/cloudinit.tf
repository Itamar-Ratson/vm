resource "terraform_data" "ssh_pubkey_check" {
  lifecycle {
    precondition {
      condition     = local.ssh_pubkey_exists
      error_message = "No SSH public key was found. Create ~/.ssh/id_ed25519.pub or ~/.ssh/id_rsa.pub, or set ssh_pubkey_path to an existing public key file."
    }
  }
}

data "cloudinit_config" "user_data" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init/user-data.yaml.tftpl", {
      ssh_public_key = local.ssh_public_key
    })
  }
}

resource "libvirt_cloudinit_disk" "user_data" {
  name      = "devops-sandbox-cloudinit.iso"
  pool      = "default"
  user_data = data.cloudinit_config.user_data.rendered
  meta_data = yamlencode({
    instance-id    = "devops-sandbox"
    local-hostname = "devops-sandbox"
  })

  depends_on = [terraform_data.ssh_pubkey_check]
}

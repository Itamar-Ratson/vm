output "vm_ip" {
  description = "Libvirt-assigned VM IP address."
  value       = libvirt_domain.vm.network_interface[0].addresses[0]
}

output "ssh_command" {
  description = "Command for SSH access to the VM."
  value       = "ssh dev@${libvirt_domain.vm.network_interface[0].addresses[0]}"
}

output "hostname" {
  description = "Hostname baked into the VM image."
  value       = "devops-sandbox"
}

output "virt_viewer_command" {
  description = "Command for opening the VM desktop with virt-viewer."
  value       = "virt-viewer --connect qemu:///system devops-sandbox"
}

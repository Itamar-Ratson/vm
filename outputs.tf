output "vm_ip" {
  description = "Libvirt-assigned VM IP address."
  value       = libvirt_domain.vm.network_interface[0].addresses[0]
}

output "ssh_command" {
  description = "Command for SSH access to the VM."
  value       = "ssh ${var.username}@${libvirt_domain.vm.network_interface[0].addresses[0]}"
}

output "virt_viewer_command" {
  description = "Command for opening the VM desktop with virt-viewer."
  value       = "virt-viewer --connect qemu:///system ${var.vm_name}"
}

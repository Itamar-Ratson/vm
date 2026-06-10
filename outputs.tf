output "vm_ip" {
  description = "Libvirt-assigned VM IP address."
  value       = data.libvirt_domain_interface_addresses.vm.interfaces[0].addrs[0].addr
}

output "ssh_command" {
  description = "Command for SSH access to the VM."
  value       = "ssh ${var.username}@${data.libvirt_domain_interface_addresses.vm.interfaces[0].addrs[0].addr}"
}

output "virt_viewer_command" {
  description = "Command for opening the VM desktop with virt-viewer."
  value       = "virt-viewer --connect qemu:///system ${var.vm_name}"
}

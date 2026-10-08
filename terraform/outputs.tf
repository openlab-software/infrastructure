output "vm_ips" {
  description = "IP de cada VM (alias do inventory => IP)"
  value       = { for alias, vm in local.vms : alias => vm.ip }
}

output "inventory_file" {
  value = local_file.ansible_inventory.filename
}

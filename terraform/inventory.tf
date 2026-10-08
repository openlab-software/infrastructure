# Gera o inventory do Ansible a partir das VMs (nada de IP duplicado à mão).
locals {
  inventory_groups = {
    for g in ["k8s_init", "k8s_control_plane", "k8s_workers", "proxy_servers", "nfs"] :
    g => [for alias, vm in local.vms : { alias = alias, ip = vm.ip } if vm.group == g]
  }
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/${var.inventory_path}"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    groups = local.inventory_groups
    user   = var.ci_user
    key    = var.ssh_private_key_path
  })
}

locals {
  gateway = cidrhost(var.lan_cidr, 1)

  masters = {
    count       = 3
    name_prefix = "k8s-master"
    vmid_prefix = 300
    cores       = 2
    sockets     = 1
    memory      = 3072
    disk_size   = "32G" # igual ou maior que o template cloud-init
    last_octet  = 20
    tags        = "masters"
  }

  workers = {
    count       = 3
    name_prefix = "k8s-worker"
    vmid_prefix = 400
    cores       = 3
    sockets     = 2
    memory      = 4608
    disk_size   = "32G"
    last_octet  = 30
    tags        = "workers"
  }

  # Chave = alias no inventory do Ansible. `group` = grupo do inventory.
  vms = merge(
    {
      for i in range(local.masters.count) : "master${i + 1}" => {
        name       = format("%s-%s", local.masters.name_prefix, i)
        vmid       = local.masters.vmid_prefix + i
        ip         = cidrhost(var.lan_cidr, local.masters.last_octet + i)
        group      = i == 0 ? "k8s_init" : "k8s_control_plane"
        cores      = local.masters.cores
        sockets    = local.masters.sockets
        memory     = local.masters.memory
        disk_size  = local.masters.disk_size
        tags       = local.masters.tags
        nameserver = null
        ssh_user   = var.ci_user
        os_type    = "cloud-init"
      }
    },
    {
      for i in range(local.workers.count) : "worker${i + 1}" => {
        name       = format("%s-%s", local.workers.name_prefix, i)
        vmid       = local.workers.vmid_prefix + i
        ip         = cidrhost(var.lan_cidr, local.workers.last_octet + i)
        group      = "k8s_workers"
        cores      = local.workers.cores
        sockets    = local.workers.sockets
        memory     = local.workers.memory
        disk_size  = local.workers.disk_size
        tags       = local.workers.tags
        nameserver = null
        ssh_user   = null
        os_type    = null
      }
    },
    {
      proxy = {
        name       = "proxy"
        vmid       = 200
        ip         = cidrhost(var.lan_cidr, 10)
        group      = "proxy_servers"
        cores      = 2
        sockets    = 2
        memory     = 4608
        disk_size  = "32G"
        tags       = null
        nameserver = "8.8.8.8 8.8.4.4"
        ssh_user   = null
        os_type    = null
      }
      nfsserver = {
        name       = "nfs-server"
        vmid       = 201
        ip         = cidrhost(var.lan_cidr, 11)
        group      = "nfs"
        cores      = 2
        sockets    = 2
        memory     = 4608
        disk_size  = "300G"
        tags       = null
        nameserver = null
        ssh_user   = null
        os_type    = null
      }
    },
  )
}

module "vm" {
  source   = "./modules/vm"
  for_each = local.vms

  name       = each.value.name
  vmid       = each.value.vmid
  ip         = each.value.ip
  gateway    = local.gateway
  template   = var.cloudinit_template
  cores      = each.value.cores
  sockets    = each.value.sockets
  memory     = each.value.memory
  disk_size  = each.value.disk_size
  tags       = each.value.tags
  nameserver = each.value.nameserver
  ssh_user   = each.value.ssh_user
  os_type    = each.value.os_type

  target_node = var.proxmox_node
  bridge      = var.lan_bridge
  storage     = var.proxmox_storage

  ci_user         = var.ci_user
  ci_password     = var.ci_password
  ssh_public_key  = file(var.ssh_public_key_path)
  ssh_private_key = file(var.ssh_private_key_path)
}

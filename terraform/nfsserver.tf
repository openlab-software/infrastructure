# resource "proxmox_vm_qemu" "nfs-server" {
#   target_node = "pve"
#   vmid        = 101
#   name        = "nfs-server"

#   onboot = true
#   clone  = var.cloudinit_template
#   agent  = 1

#   cores   = 2
#   memory  = 4608
#   sockets = 2

#   ciuser     = "ubuntu"
#   cipassword = "ubuntu"
#   sshkeys    = file("~/.ssh/id_rsa.pub")
#   ipconfig0 = format(
#     "ip=%s/24,gw=%s",
#     cidrhost(
#       local.cidr,
#       local.masters.network_last_octect + count.index
#     ),
#     cidrhost(local.cidr, 1)
#   )

#   network {
#     id     = 0
#     bridge = local.bridge.interface
#     model  = local.bridge.model
#   }

#   scsihw = local.scsihw

#   serial {
#     id   = local.serial.id
#     type = local.serial.type
#   }

#   disk {
#     backup  = local.disks.cloudinit.backup
#     format  = local.disks.cloudinit.format
#     type    = local.disks.cloudinit.type
#     storage = local.disks.cloudinit.storage
#     slot    = local.disks.cloudinit.slot
#   }

#   disk {
#     backup  = local.disks.main.backup
#     format  = local.disks.main.format
#     type    = local.disks.main.type
#     storage = local.disks.main.storage
#     size    = local.masters.disk_size
#     slot    = local.disks.main.slot
#     discard = local.disks.main.discard
#   }

#   tags = local.masters.tags
# }

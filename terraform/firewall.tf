# resource "proxmox_vm_qemu" "proxy" {
#   target_node = "pve"
#   vmid        = 200
#   name        = "proxy"

#   onboot = true
#   clone  = var.cloudinit_template
#   agent  = 1

#   cores   = 2
#   memory  = 4608
#   sockets = 2

#   ciuser          = "ubuntu"
#   cipassword      = "ubuntu"
#   sshkeys         = file("~/.ssh/id_ed25519.pub")
#   ssh_private_key = file("~/.ssh/id_ed25519")

#   nameserver = "8.8.8.8 8.8.4.4"

#   ipconfig0 = format(
#     "ip=%s/24,gw=%s",
#     cidrhost(var.lan_cidr, 10),
#     cidrhost(var.lan_cidr, 1)
#   )

#   network {
#     id     = 0
#     bridge = var.lan_bridge
#     model  = "virtio"
#   }

#   scsihw = "virtio-scsi-pci"

#   serial {
#     id   = 0
#     type = "socket"
#   }

#   disk {
#     backup  = true
#     format  = "raw"
#     type    = "cloudinit"
#     storage = "os"
#     slot    = "ide2"
#   }

#   disk {
#     backup  = true
#     format  = "raw"
#     type    = "disk"
#     storage = "os"
#     slot    = "scsi0"
#     discard = true
#     size    = "32G"
#   }
# }

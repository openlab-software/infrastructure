# resource "proxmox_vm_qemu" "firewall" {
#   name        = "OPNSense"
#   target_node = "pve"

#   cores   = 4
#   memory  = 5120
#   sockets = 1
#   scsihw  = "virtio-scsi-pci"
#   boot    = "order=ide2;scsi0"
#   onboot  = true

#   disks {
#     scsi {
#       scsi0 {
#         disk {
#           size    = "32G"
#           storage = "os"
#         }
#       }
#     }
#     ide {
#       ide2 {
#         cdrom {
#           iso = var.firewall_iso
#         }
#       }
#     }
#   }

#   network {
#     id     = 0
#     model  = "virtio"
#     bridge = var.wan_bridge
#   }

#   network {
#     id     = 1
#     model  = "virtio"
#     bridge = var.lan_bridge
#   }

#   sshkeys = file("~/.ssh/id_ed25519.pub")
# }

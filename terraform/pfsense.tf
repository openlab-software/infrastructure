resource "proxmox_vm_qemu" "pfsense" {
  name        = "pfSense"
  # target_node = var.pm_node
  iso         = var.pfsense_iso
  cores       = 2
  memory      = 2048
  sockets     = 1
  scsihw      = "virtio-scsi-pci"
  boot        = "order=ide2;scsi0"
  onboot      = true

  disk {
    type    = "scsi"
    storage = "local-lvm"
    size    = "10G"
  }

  network {
    model  = "virtio"
    bridge = var.wan_bridge
  }

  network {
    model  = "virtio"
    bridge = var.lan_bridge
  }

  sshkeys = file("~/.ssh/id_rsa.pub")
}

# Uma VM Proxmox clonada de um template cloud-init, com IP fixo.
resource "proxmox_vm_qemu" "vm" {
  target_node = var.target_node
  vmid        = var.vmid
  name        = var.name

  onboot = true
  clone  = var.template
  agent  = 1

  cores   = var.cores
  sockets = var.sockets
  memory  = var.memory

  ciuser     = var.ci_user
  cipassword = var.ci_password

  ssh_user = var.ssh_user
  os_type  = var.os_type

  sshkeys         = var.ssh_public_key
  ssh_private_key = var.ssh_private_key

  nameserver = var.nameserver

  ipconfig0 = format("ip=%s/24,gw=%s", var.ip, var.gateway)

  network {
    id     = 0
    bridge = var.bridge
    model  = "virtio"
  }

  scsihw = "virtio-scsi-pci"

  # serial é necessário para o console da WebGUI
  serial {
    id   = 0
    type = "socket"
  }

  disk {
    backup  = true
    format  = "raw"
    type    = "cloudinit"
    storage = var.storage
    slot    = "ide2"
  }

  disk {
    backup  = true
    format  = "raw"
    type    = "disk"
    storage = var.storage
    size    = var.disk_size
    slot    = "scsi0"
    discard = true
  }

  tags = var.tags
}

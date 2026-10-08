# As VMs já criadas pela versão anterior (resources soltos) passam a ser instâncias do módulo.
# Sem estes blocos o Terraform destruiria e recriaria as VMs.

moved {
  from = proxmox_vm_qemu.k8s-masters[0]
  to   = module.vm["master1"].proxmox_vm_qemu.vm
}

moved {
  from = proxmox_vm_qemu.k8s-masters[1]
  to   = module.vm["master2"].proxmox_vm_qemu.vm
}

moved {
  from = proxmox_vm_qemu.k8s-masters[2]
  to   = module.vm["master3"].proxmox_vm_qemu.vm
}

moved {
  from = proxmox_vm_qemu.k8s-workers[0]
  to   = module.vm["worker1"].proxmox_vm_qemu.vm
}

moved {
  from = proxmox_vm_qemu.k8s-workers[1]
  to   = module.vm["worker2"].proxmox_vm_qemu.vm
}

moved {
  from = proxmox_vm_qemu.k8s-workers[2]
  to   = module.vm["worker3"].proxmox_vm_qemu.vm
}

moved {
  from = proxmox_vm_qemu.proxy
  to   = module.vm["proxy"].proxmox_vm_qemu.vm
}

moved {
  from = proxmox_vm_qemu.nfs-server
  to   = module.vm["nfsserver"].proxmox_vm_qemu.vm
}

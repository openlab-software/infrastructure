variable "pm_api_url" {
  type        = string
  description = "Proxmox JSON API"
  default     = "https://192.168.0.2:8006/api2/json"
}

variable "pm_api_token_id" {
  type        = string
  description = "User Proxmox API token ID created by provider(telmate/proxmox) docs https://registry.terraform.io/providers/Telmate/proxmox/latest/docs"
}

variable "pm_api_token_secret" {
  type        = string
  description = "Proxmox API token secret"
}

variable "lan_bridge" {
  type        = string
  description = "Name of the LAN bridge on Proxmox server. e.g.: vmbr1"
}

variable "lan_cidr" {
  type        = string
  description = "LAN CIDR"
  default     = "10.0.0.0/24"
}

variable "cloudinit_template" {
  type    = string
  default = "ubuntu-2404-cloud-init"
}

variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "proxmox_storage" {
  type    = string
  default = "os"
}

variable "ci_user" {
  type    = string
  default = "ubuntu"
}

variable "ci_password" {
  type      = string
  sensitive = true
  default   = "ubuntu"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519"
}

variable "inventory_path" {
  type        = string
  description = "Onde gravar o inventory do Ansible (relativo a esta pasta)"
  default     = "../environments/prod/inventory.ini"
}

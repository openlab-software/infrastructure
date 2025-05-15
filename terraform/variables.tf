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

variable "wan_bridge" {
  type        = string
  description = "Name of the WAN bridge on Proxmox server"
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

variable "pfsense_iso" {
  type        = string
  description = "path to .iso. e.g.: 'local:iso/pfSense-CE-2.7.1-RELEASE-amd64.iso'"
}


variable "cloudinit_template" {
  type    = string
  default = "ubuntu-2404-cloud-init"
}

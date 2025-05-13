variable "pm_api_url" {
    type = string
    description = "Proxmox JSON API"
    default = "https://192.168.0.2:8006/api2/json"
}

variable "pm_api_token_id" {
  type = string
  description = "User Proxmox API token ID created by provider(telmate/proxmox) docs https://registry.terraform.io/providers/Telmate/proxmox/latest/docs"
}

variable "pm_api_token_secret" {
  type = string
  description = "Proxmox API token secret"
}
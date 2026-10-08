variable "name" {
  type = string
}

variable "vmid" {
  type = number
}

variable "ip" {
  type        = string
  description = "IP da VM (sem máscara; /24)"
}

variable "gateway" {
  type = string
}

variable "template" {
  type        = string
  description = "Template cloud-init a clonar"
}

variable "cores" {
  type = number
}

variable "sockets" {
  type = number
}

variable "memory" {
  type        = number
  description = "MB"
}

variable "disk_size" {
  type = string
}

variable "target_node" {
  type    = string
  default = "pve"
}

variable "bridge" {
  type = string
}

variable "storage" {
  type    = string
  default = "os"
}

variable "tags" {
  type    = string
  default = null
}

variable "nameserver" {
  type    = string
  default = null
}

variable "ssh_user" {
  type        = string
  default     = null
  description = "Usuário do provider ao conectar via SSH (opcional)"
}

variable "os_type" {
  type    = string
  default = null
}

variable "ci_user" {
  type = string
}

variable "ci_password" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  type = string
}

variable "ssh_private_key" {
  type      = string
  sensitive = true
}

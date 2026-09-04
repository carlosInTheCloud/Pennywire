variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}


variable "admin_email" {
  type      = string
  sensitive = true
}

variable "admin_initial_password" {
  type      = string
  sensitive = true
}

variable "wireguard_private_key" {
  description = "The private key for the WireGuard server"
  type        = string
  sensitive   = true
}

variable "client_public_keys" {
  description = "Comma-separated list of client public keys"
  type        = string
}

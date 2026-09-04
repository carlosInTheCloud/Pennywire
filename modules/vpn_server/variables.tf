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

variable "instance_type" {
  description = "EC2 instance type for the VPN server. t3.micro is free-tier eligible; t3.nano is the cheapest steady-state option."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Size in GB of the EC2 root volume. WireGuard and the CloudWatch agent fit comfortably in 8 GB."
  type        = number
  default     = 8
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

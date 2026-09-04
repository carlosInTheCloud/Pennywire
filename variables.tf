variable "aws_region" {
  description = "The default AWS region for the provider"
  type        = string
  default     = "us-east-1"
}

variable "deploy_us_east_1" {
  description = "Feature flag to deploy the VPN in us-east-1"
  type        = bool
  default     = false
}

variable "budget_alert_email" {
  description = "The email address to send AWS budget alerts to"
  type        = string
  sensitive   = true
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

variable "aws_profile" {
  description = "Named AWS CLI/SSO profile to authenticate with. Leave null to use AWS_PROFILE or the default credential chain."
  type        = string
  default     = null
}

variable "owner_tag" {
  description = "Value applied to the Owner tag on every resource"
  type        = string
  default     = "vpn-admin"
}

variable "admin_email" {
  description = "Email address of the Cognito administrator allowed to sign in to the key manager"
  type        = string
  sensitive   = true
}

variable "admin_initial_password" {
  description = "Temporary password for the Cognito administrator. Change it on first sign-in; it is ignored on subsequent applies."
  type        = string
  sensitive   = true
}

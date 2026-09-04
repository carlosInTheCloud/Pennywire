module "vpn_server_us_east_1" {
  source = "./modules/vpn_server"

  count = var.deploy_us_east_1 ? 1 : 0

  aws_region  = "us-east-1"
  vpc_cidr    = "10.0.0.0/16"
  subnet_cidr = "10.0.1.0/24"

  instance_type    = var.instance_type
  root_volume_size = var.root_volume_size

  wireguard_private_key  = var.wireguard_private_key
  client_public_keys     = var.client_public_keys
  admin_email            = var.admin_email
  admin_initial_password = var.admin_initial_password
}

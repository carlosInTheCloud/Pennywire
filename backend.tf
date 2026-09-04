terraform {
  backend "s3" {
    key            = "vpn-server/terraform.tfstate"
    dynamodb_table = "vpn-server-tfstate-lock"
    encrypt        = true
  }
}

resource "aws_dynamodb_table" "vpn_clients" {
  name         = "vpn-clients-${var.aws_region}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PublicKey"

  attribute {
    name = "PublicKey"
    type = "S"
  }

  tags = {
    Name = "vpn-clients-table"
  }
}

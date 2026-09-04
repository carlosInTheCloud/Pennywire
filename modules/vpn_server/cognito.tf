resource "aws_cognito_user_pool" "admin_pool" {
  name = "vpn-admin-pool-${var.aws_region}"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  mfa_configuration = "ON"

  software_token_mfa_configuration {
    enabled = true
  }

  username_attributes = ["email"]
  
  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "webapp_client" {
  name         = "vpn-webapp-client-${var.aws_region}"
  user_pool_id = aws_cognito_user_pool.admin_pool.id
  
  generate_secret = false
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

resource "aws_cognito_user" "admin_user" {
  user_pool_id = aws_cognito_user_pool.admin_pool.id
  username     = var.admin_email
  
  attributes = {
    email          = var.admin_email
    email_verified = true
  }
  
  # For a production deployment, this should be injected securely via a variable
  password = var.admin_initial_password

  lifecycle {
    ignore_changes = [password]
  }
}

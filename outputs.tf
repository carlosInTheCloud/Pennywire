# Values needed to configure the Key Manager web app and connect clients.
# Each returns null when the corresponding region's feature flag is false.

output "vpn_public_ip" {
  description = "Elastic IP of the us-east-1 VPN server"
  value       = one(module.vpn_server_us_east_1[*].vpn_public_ip)
}

output "webapp_url" {
  description = "URL of the Key Manager web app once the build is uploaded"
  value       = one(module.vpn_server_us_east_1[*].webapp_url)
}

output "webapp_bucket" {
  description = "S3 bucket to sync the Key Manager build into"
  value       = one(module.vpn_server_us_east_1[*].webapp_bucket)
}

output "api_url" {
  description = "VITE_API_ENDPOINT for the web app's .env"
  value       = one(module.vpn_server_us_east_1[*].api_url)
}

output "cognito_user_pool_id" {
  description = "VITE_COGNITO_USER_POOL_ID for the web app's .env"
  value       = one(module.vpn_server_us_east_1[*].cognito_user_pool_id)
}

output "cognito_client_id" {
  description = "VITE_COGNITO_CLIENT_ID for the web app's .env"
  value       = one(module.vpn_server_us_east_1[*].cognito_client_id)
}

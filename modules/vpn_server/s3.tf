resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "webapp" {
  bucket        = "vpn-key-manager-webapp-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "webapp_public_access_block" {
  bucket = aws_s3_bucket.webapp.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "webapp_policy" {
  bucket = aws_s3_bucket.webapp.id
  depends_on = [aws_s3_bucket_public_access_block.webapp_public_access_block]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.webapp.arn}/*"
      }
    ]
  })
}

output "webapp_url" {
  value       = "https://${aws_s3_bucket.webapp.bucket_regional_domain_name}/index.html"
  description = "The secure HTTPS URL for the VPN Key Manager Web App"
}

output "api_url" {
  value       = aws_apigatewayv2_api.vpn_api.api_endpoint
  description = "The HTTP API Gateway URL for the backend"
}

output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.admin_pool.id
}

output "cognito_client_id" {
  value       = aws_cognito_user_pool_client.webapp_client.id
}

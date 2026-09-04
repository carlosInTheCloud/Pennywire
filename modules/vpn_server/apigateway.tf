resource "aws_apigatewayv2_api" "vpn_api" {
  name          = "vpn-api-${var.aws_region}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://${aws_s3_bucket.webapp.bucket_regional_domain_name}"]
    allow_methods = ["GET", "POST", "OPTIONS", "DELETE"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.vpn_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "vpn-cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.webapp_client.id]
    issuer   = "https://${aws_cognito_user_pool.admin_pool.endpoint}"
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.vpn_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.vpn_api.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_clients" {
  api_id    = aws_apigatewayv2_api.vpn_api.id
  route_key = "GET /clients"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "post_clients" {
  api_id    = aws_apigatewayv2_api.vpn_api.id
  route_key = "POST /clients"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "delete_clients" {
  api_id    = aws_apigatewayv2_api.vpn_api.id
  route_key = "DELETE /clients/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.vpn_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vpn_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.vpn_api.execution_arn}/*/*"
}

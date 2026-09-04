resource "aws_security_group" "vpn" {
  name        = "vpn-server-sg"
  description = "Security group for WireGuard VPN server"
  vpc_id      = aws_vpc.vpn.id

  ingress {
    description = "WireGuard UDP"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }



  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "vpn_instance_role" {
  name = "vpn-instance-role-${var.aws_region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "vpn_instance_policy" {
  name        = "vpn-instance-policy-${var.aws_region}"
  description = "Permissions for VPN server EC2 instance"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:AssociateAddress",
          "ec2:DescribeAddresses"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Effect = "Allow"
        Resource = [
          aws_ssm_parameter.wireguard_private_key.arn
        ]
      },
      {
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "dynamodb:Scan",
          "dynamodb:PutItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.vpn_clients.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vpn_policy_attachment" {
  role       = aws_iam_role.vpn_instance_role.name
  policy_arn = aws_iam_policy.vpn_instance_policy.arn
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.vpn_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "vpn_instance_profile" {
  name = "vpn-instance-profile-${var.aws_region}"
  role = aws_iam_role.vpn_instance_role.name
}

resource "aws_ssm_parameter" "wireguard_private_key" {
  name        = "/vpn-server/${var.aws_region}/wireguard-private-key"
  description = "Private key for the WireGuard server in ${var.aws_region}"
  type        = "SecureString"
  value       = var.wireguard_private_key
}

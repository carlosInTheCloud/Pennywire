resource "aws_eip" "vpn" {
  domain = "vpc"
}

data "aws_default_tags" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_launch_template" "vpn" {
  name_prefix   = "vpn-server-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.vpn_instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.vpn.id]
    subnet_id                   = aws_subnet.public.id
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    EIP_ALLOCATION_ID = aws_eip.vpn.id
    REGION            = var.aws_region
    WG_PORT           = 51820
    CLIENT_PUB_KEYS   = var.client_public_keys
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      { Name = "vpn-server-instance" },
      data.aws_default_tags.current.tags
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "vpn" {
  name                = "vpn-server-asg-${var.aws_region}"
  vpc_zone_identifier = [aws_subnet.public.id]
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.vpn.id
    version = "$Latest"
  }
}

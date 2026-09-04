output "vpn_public_ip" {
  description = "The public Elastic IP address of the VPN server"
  value       = aws_eip.vpn.public_ip
}

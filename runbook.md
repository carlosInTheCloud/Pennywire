# VPN Server Runbook

This runbook outlines operational procedures and troubleshooting steps for the AWS WireGuard VPN server.

## Self-Healing Architecture Overview

The VPN server does not rely on a static, fragile EC2 instance. Instead, it utilizes an **AWS Auto Scaling Group (ASG)** configured to ensure exactly 1 instance is running at all times. 

If the underlying EC2 instance experiences hardware failure, becomes unresponsive, or if the initial boot script (`userdata.sh`) crashes due to temporary network issues, the best way to fix the VPN is to completely destroy the instance and let the ASG heal it automatically.

When a new instance is spun up by the ASG, it will automatically:
1. Download your WireGuard Server Private Key from AWS Systems Manager (SSM)
2. Build the `wg0.conf` configuration file and insert the allowed client public keys
3. Start the WireGuard service and configure `iptables` NAT routing
4. Dynamically re-attach the static Elastic IP address so your clients don't drop

## 🔑 AWS CLI Authentication (Prerequisite)

Before running any AWS CLI commands in this runbook, you must ensure your terminal is authenticated. Because this project uses secure IAM Identity Center (SSO), you must log in to refresh your temporary session tokens.

Run the following command, replacing the placeholder with your own SSO profile name:
```bash
aws sso login --profile <your-profile-name>
```
*For detailed setup instructions on configuring the CLI, refer to the [AWS Setup Guide](.agents/rules/aws_setup_guide.md).*
## 🛑 How to Restart / Heal the VPN Server

If your VPN is unresponsive or you suspect the boot script failed, **do not attempt to SSH into the server to fix it manually**. Instead, force the Auto Scaling Group to replace the instance.

Run the following command in your local terminal to automatically find the running VPN instance and terminate it:

```bash
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=vpn-server" "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text) && \
echo "Terminating $INSTANCE_ID..." && \
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

**What to expect:**
1. The command will output `Terminating i-xxxxxxxxx...` and show the AWS termination response.
2. Wait approximately **2 to 3 minutes**.
3. During this time, the ASG will detect the failure, provision a replacement instance, and run the boot sequence.
4. Your VPN connections will automatically resume once the new server is online and the Elastic IP is re-attached.

## 📊 How to Check Logs

If you want to verify that the new instance booted correctly, check the centralized CloudWatch logs.

Run this command locally to tail the latest logs from the server's boot sequence:
```bash
aws logs tail /vpn-server/syslog --since 10m
```

Look for the following healthy indicators:
* `Starting WireGuard via wg-quick(8) for wg0...`
* `wireguard: WireGuard 1.0.0 loaded.`
* `Finished WireGuard via wg-quick(8) for wg0.`
* `net.ipv4.ip_forward = 1`

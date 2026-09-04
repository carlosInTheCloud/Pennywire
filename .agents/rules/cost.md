---
name: cost_management
description: Cost management guidelines and AWS budget alerts
trigger: always_on
---

# VPN Server Cost Documentation

## Cost Breakdown

| Component | Cost Description (how it gets charged) | Base Charge |
| :--- | :--- | :--- |
| **VPC & Subnets** | N/A | N/A |
| **Internet Gateway** | N/A | N/A |
| **Route Tables** | N/A | N/A |
| **Security Groups** | N/A | N/A |
| **WireGuard Software** | N/A | N/A |
| **EC2 Instance (Compute)** | Charged per second while running, based on the chosen instance type (e.g., `t3.nano` or `t3.micro`). | ~$0.0052 per hour (e.g., `t3.nano` in us-east-1) |
| **EBS Volume (Storage)** | Charged per GB-month of provisioned storage for the EC2 instance's root disk. | ~$0.08 per GB-month (gp3 storage) |
| **Elastic IP / Public IPv4** | Charged per hour for the allocated public IPv4 address associated with the VPN server. | $0.005 per IP per hour |
| **Data Transfer (Outbound)** | Charged per GB of data transferred out from the EC2 instance to the internet (client internet traffic). | $0.09 per GB (First 100 GB/month free) |

## Estimated Fixed Monthly Cost (24x7 Uptime)

If the VPN server is left running continuously (approx. 730 hours/month) with an 8 GB root volume, the baseline monthly cost in `us-east-1` would be roughly:

- **EC2 Instance (`t3.nano`)**: ~$3.80
- **EBS Volume (8 GB `gp3`)**: ~$0.64
- **Elastic IP (Public IPv4)**: ~$3.65
- **Total Fixed Cost**: **~$8.09 / month**

*Note: This total excludes Outbound Data Transfer, which is highly variable based on client internet usage (though the first 100 GB/month is free).*

## Cost Management & Alerts

To prevent unexpected spikes in cost (primarily due to variable Outbound Data Transfer), a global **AWS Budget** is provisioned automatically alongside the infrastructure via Terraform.

- **Threshold Monitoring:** The budget tracks the total combined cost of the VPN infrastructure across all AWS regions.
- **Alerting Mechanism:** If actual or forecasted monthly spending exceeds the configured safety threshold of **$25.00**, an automated email alert is immediately dispatched to the administrator's email address.
- **Security & Privacy:** The alert email address is injected into Terraform dynamically via a secure variable during deployment. It is strictly excluded from version control to protect personal information.
- **Budget Cost:** $0.00 (AWS provides the first two active budgets for free).

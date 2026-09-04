---
name: observability_strategy
description: Strategy for logging, metrics, and dashboards using AWS CloudWatch
trigger: always_on
---

# Observability & Troubleshooting

Because the VPN infrastructure relies on an Auto Scaling Group (ASG) for self-healing, the EC2 instances are entirely ephemeral. If a server crashes, its local hard drive (and local logs) are destroyed immediately upon replacement. 

To ensure we can troubleshoot issues and monitor the health of the VPN, we rely on **Amazon CloudWatch** for centralized logging and metrics dashboards.

## 1. Centralized Logging

The EC2 instance uses the Unified CloudWatch Agent to automatically stream local system and kernel logs to AWS CloudWatch Logs. 

- **Log Group:** `/vpn-server/syslog`
- **Data Captured:** System boot logs, systemd service logs (`wg-quick`), and WireGuard kernel ring buffer logs (`dmesg`).

### How to View the Logs

**Option A: AWS Console (Web UI)**
1. Log into the AWS Management Console.
2. Navigate to **CloudWatch > Log groups**.
3. Click on `/vpn-server/syslog`.
4. Select the most recent Log Stream to view the chronological server logs.

**Option B: AWS CLI (Terminal)**
You can tail the logs directly from your local terminal using the AWS CLI:
```bash
aws logs tail /vpn-server/syslog --follow
```

## 2. Metrics & Dashboards

A custom **CloudWatch Dashboard** is provisioned automatically via Terraform. This provides a single pane of glass to monitor the performance and health of the VPN server.

### Available Dashboard Metrics
- **Network In / Out (Bytes):** Critical for a VPN server to monitor client data transfer and identify bandwidth spikes.
- **CPU Utilization:** To ensure the instance has sufficient compute capacity for encryption overhead.
- **Status Check Failed:** To monitor hardware or network impairments at the AWS infrastructure level.

### How to View the Dashboard
1. Log into the AWS Management Console.
2. Navigate to **CloudWatch > Dashboards**.
3. Select the `vpn-server-dashboard`.

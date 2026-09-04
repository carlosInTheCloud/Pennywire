---
name: project_goal
description: Project goals, scope, and non-functional requirements
trigger: always_on
---

# Goal
The primary objective of this project is to build a highly available, robust, and extremely cost-efficient VPN server. By utilizing WireGuard—a modern, lightweight, and fast VPN protocol—clients will be able to securely tunnel their internet traffic through a trusted network. The solution is designed to act as a personal or small-team VPN, prioritizing low operational overhead and maximum cost savings over complex enterprise routing features.

## Scope
The scope of this project encompasses the automated deployment of a WireGuard server to one or many AWS regions. 

Key constraints and deliverables include:
- **Infrastructure as Code (IaC):** The entire lifecycle of the server, from networking to compute provisioning, must be managed entirely via Terraform.
- **High Availability (HA):** The architecture must be "self-healing," capable of surviving the failure of an underlying EC2 instance without manual intervention, while adhering to strict cost limits.
- **Multi-Region Support:** The Terraform configuration must support on-demand, multi-region deployments via modular feature flags, ensuring that idle regions do not accumulate passive costs (e.g., unattached Elastic IPs).
- **Cost Optimization:** The core components should rely on free-tier eligible or extremely low-cost AWS resources (like `t3.nano` instances), targeting a baseline fixed cost of under $10/month per active region.

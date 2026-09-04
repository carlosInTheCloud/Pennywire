---
name: vpn_architecture
description: Architectural rules and guidelines for the WireGuard VPN server
trigger: always_on
---

# Architecture

The infrastructure will be defined, provisioned, and managed entirely through **Terraform** to ensure reproducibility and infrastructure-as-code best practices.

## Components

1. **Networking (VPC & Subnets):**
   - A dedicated Virtual Private Cloud (VPC) in the target AWS region(s).
   - Public Subnet(s) with an Internet Gateway attached to allow external internet connectivity.
   - Route tables directing outbound traffic to the Internet Gateway.

2. **Compute (EC2):**
   - EC2 instance(s) running a supported Linux distribution (e.g., Ubuntu Server).
   - The instance will be provisioned in the Public Subnet.
   - An Elastic IP (EIP) associated with each instance to provide a static, reliable public IP address for WireGuard clients to connect to.
   - User Data scripts (provisioned via Terraform) to automatically install the WireGuard software, configure the network interfaces, enable IP forwarding, and set up the `wg0` interface upon boot.

3. **Security:**
   - **Security Groups:** Configured to strictly control access:
     - **Inbound:** Allow UDP traffic on port `51820` (default WireGuard port) from any source (`0.0.0.0/0`). SSH is disabled; use AWS Systems Manager (SSM) for secure shell access.
     - **Outbound:** Allow all traffic (`0.0.0.0/0`) to route client internet traffic.

4. **WireGuard Software:**
   - Installed on the EC2 instance.
   - Configured with server private/public keys.
   - IPTables/UFW rules to handle NAT/masquerading so client traffic is correctly routed out to the internet through the EC2 instance's primary network interface.

5. **Dynamic Key Management (Serverless):**
   - **DynamoDB:** Acts as the central source of truth for active WireGuard client public keys and server endpoint IPs.
   - **API Gateway & Lambda:** Provides a secured REST API for the frontend Web App to issue or revoke client keys.
   - **Cognito:** Secures the API Gateway using JWT authorizers to ensure only authenticated administrators can manage keys.
   - **Instance Sync Script:** The EC2 instance runs a recurring background script (via `cron`) that polls DynamoDB every minute. It automatically synchronizes the local WireGuard configuration (`wg syncconf`) with the latest peers without dropping existing connections.

## High Availability (HA) & Disaster Recovery

To achieve High Availability without significantly increasing costs, the VPN server relies on an **Active/Passive Self-Healing** architecture. 

- **Auto Scaling Group (ASG):** The single EC2 instance is deployed within an ASG with a minimum, maximum, and desired capacity of `1`. If the underlying hardware fails or the instance crashes, the ASG will automatically terminate it and provision a replacement.
- **State Management:** The replacement instance utilizes a User Data script to retrieve the original WireGuard Private Key from AWS Systems Manager (SSM) Parameter Store.
- **Endpoint Persistence:** Upon boot, the new instance uses the AWS CLI to re-associate the existing Elastic IP (EIP) to itself, ensuring that client configurations do not need to be updated.

### Alternative HA Solutions Reviewed

1. **Route 53 DNS Failover (Active/Passive across 2 AZs):** Running two separate EC2 instances in different availability zones and using Route 53 health checks to failover a DNS record. 
   * **Reason for Rejection:** Doubles the compute cost and adds Route 53 health check fees. Additionally, DNS TTL caching can delay client failover.
2. **Network Load Balancer (NLB):** Placing a UDP-compatible NLB in front of multiple EC2 instances. 
   * **Reason for Rejection:** Cost prohibitive. An NLB incurs a fixed hourly charge of roughly ~$16/month, which alone doubles the baseline budget of this project before factoring in compute costs.

## Multi-Region Support

The infrastructure is designed to support simultaneous deployments across multiple global regions (e.g., US East, US West, Europe) using Terraform modularity.

- **Infrastructure as Code (IaC) Feature Flags:** The Terraform configuration will use boolean variables (e.g., `deploy_europe = true/false`) to dictate whether a region is active. If disabled, Terraform ensures no resources exist in that region, completely eliminating idle costs (such as charges for unattached Elastic IPs). When enabled, a fully functional VPN endpoint spins up in ~2 minutes.
- **Client Connectivity (Multiple Profiles):** Users will manage connectivity via multiple distinct profiles within their WireGuard client app (e.g., "VPN - US East", "VPN - Europe"). The user manually selects which regional endpoint to connect to.

### Alternative Multi-Region Solutions Reviewed

1. **Route 53 Latency-Based Routing:** Using a single domain name and relying on AWS Route 53 to automatically route the user to the active region with the lowest latency.
   * **Reason for Rejection:** Incurs recurring monthly costs for Route 53 Hosted Zones and advanced routing health checks. 
2. **AWS Global Accelerator:** Providing a single, static global IP address that uses the AWS backbone to seamlessly route user traffic to the nearest healthy VPN region.
   * **Reason for Rejection:** Cost prohibitive. Global Accelerator has a fixed base cost of ~$18/month plus premium data transfer rates, easily tripling the baseline budget.

## Terraform State Persistence

To ensure safe collaboration, protect sensitive variables, and prevent state corruption during deployments, the infrastructure relies on a remote AWS backend for Terraform state management.

- **Amazon S3 (Storage):** The `terraform.tfstate` file is securely stored in a private S3 bucket. Bucket versioning is enabled to allow quick rollbacks in the event of state file corruption.
- **Amazon DynamoDB (State Locking):** A dedicated DynamoDB table is used to lock the state file during `terraform apply` operations. This prevents concurrent execution from corrupting the infrastructure state.

### Alternative State Solutions Reviewed

1. **Local State (`terraform.tfstate` committed to Git):**
   * **Reason for Rejection:** Highly insecure. Terraform state often contains sensitive information in plaintext. Committing it to a repository creates a major security risk and makes team collaboration nearly impossible without causing state corruption.
2. **HashiCorp Terraform Cloud (HCP):**
   * **Reason for Rejection:** While HCP offers a generous free tier and built-in locking, the S3+DynamoDB approach was chosen to keep 100% of the architecture and its dependencies contained entirely within the AWS ecosystem, minimizing third-party platform reliance.

## Resource Management & Tracking

To prevent the AWS account from becoming cluttered and to easily identify infrastructure ownership, all components of the VPN server are strictly tracked using automated tags.

- **Terraform `default_tags`:** The AWS Provider is configured with a global `default_tags` block. Terraform automatically intercepts every resource it creates (VPCs, EC2 instances, EBS volumes, Elastic IPs) and stamps them with the following standardized tags, guaranteeing 100% tag coverage with zero manual effort:
  - `Project`: `vpn-server`
  - `Environment`: `production`
  - `ManagedBy`: `terraform`
  - `Owner`: value of the `owner_tag` variable (defaults to `vpn-admin`)
- **AWS Resource Groups:** The AWS Console utilizes Resource Groups to query the `Project` tag, creating a single, unified dashboard that lists every piece of infrastructure associated with the VPN server across the account.
- **Billing Isolation:** AWS Cost Explorer and Budgets use these identical tags to isolate the exact cost of the VPN server independently from any other workloads in the account.

## Architecture Diagram

```mermaid
flowchart TD
    %% Users & Interfaces
    Admin([Administrator])
    VPNClient([VPN Client Device])
    
    %% Networking
    IGW[Internet Gateway]
    
    %% Compute & Logic
    EC2["EC2 Instance (WireGuard)"]
    APIGW[API Gateway]
    Lambda[AWS Lambda]
    
    %% Storage & Identity
    DynamoDB[(DynamoDB Table)]
    SSM[SSM Parameter Store]
    Cognito[AWS Cognito]
    
    %% Relationships
    Admin -->|1. Authenticate| Cognito
    Admin -->|2. Manage Keys| APIGW
    APIGW -->|3. Invoke| Lambda
    Lambda -->|4. Read/Write| DynamoDB
    
    EC2 -->|5. Fetch Server Key| SSM
    EC2 -->|6. Cron Sync (1 min)| DynamoDB
    
    VPNClient -->|7. UDP 51820 Tunnel| EC2
    EC2 -->|8. NAT Outbound| IGW
```

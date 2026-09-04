---
name: implementation_plan
description: Step-by-step implementation plan for the Terraform codebase
trigger: always_on
---

# Terraform Implementation: AWS WireGuard VPN

This plan outlines the steps and code structure required to deploy the highly available, cost-optimized WireGuard VPN server on AWS using Terraform, adhering to all the architectural rules established in the `.agents/rules/` documentation.

## User Review Required
> [!NOTE]
> The plan has been updated to include the new CloudWatch Observability strategy. Please review the changes in **Phase 4: VPN Module** and hit Proceed if it looks good!

## Proposed Changes

The Terraform code will be structured into a reusable module to support our "Feature Flag" multi-region design.

### Phase 1: Terraform Backend Bootstrap
To avoid migrating local state, we will create a dedicated `bootstrap/` folder containing a minimal Terraform script. We will run this *once* locally to provision the state backend. The main VPN project will then use this remote backend from day one.
- **S3 Bucket:** Deployed in `us-east-1` with versioning enabled.
- **DynamoDB Table:** Deployed in `us-east-1` for state locking.

### Phase 2: Terraform Root & Provider Config
These files orchestrate the deployment and connect to AWS.
#### [NEW] `providers.tf`
- Configures the `aws` provider.
- Injects the `default_tags` block (`Project`, `Environment`, `ManagedBy`, `Owner`).
#### [NEW] `backend.tf`
- Configures the S3 bucket and DynamoDB table created in Phase 1 for state locking.
#### [NEW] `variables.tf` / `terraform.tfvars`
- Defines the multi-region feature flags (e.g., `deploy_us_east_1 = true`).
- Defines budget thresholds and the administrator email address.

### Phase 3: Global Resources (Cost Management)
Resources that span the entire account.
#### [NEW] `budgets.tf`
- Uses `aws_budgets_budget` to track the total spend of resources tagged with `Project = vpn-server`.
- Sets an alert at $25.00/month routed to the email supplied in `budget_alert_email`.
> [!IMPORTANT]
> **Budget Clarification:** This is strictly an **alerting** mechanism (it sends a warning email). It does *not* automatically destroy or disable your infrastructure to prevent costs. Shutting off infrastructure automatically can cause catastrophic data loss or lock you out of resources, so AWS requires manual intervention by design. 

### Phase 4: VPN Module (`modules/vpn_server/`)
This module will be called once for every active region. 

#### [NEW] `modules/vpn_server/network.tf`
- **VPC & Subnets:** Creates a VPC and a public subnet.
- **Internet Gateway & Routes:** Attaches an IGW and points the subnet `0.0.0.0/0` route to it.

#### [NEW] `modules/vpn_server/security.tf`
- **Security Group:** Allows UDP `51820` (WireGuard) and TCP `22` (SSH).
- **IAM Role & Instance Profile:** Grants the EC2 instance permission to read its WireGuard private key from SSM, re-associate the Elastic IP, and **write logs to CloudWatch**.

#### [NEW] `modules/vpn_server/observability.tf`
- **CloudWatch Log Group:** Provisions `/vpn-server/syslog` for persistent log storage across instance replacements.
- **CloudWatch Dashboard:** Provisions a dashboard monitoring Network In/Out, CPU Utilization, and Status Checks.

#### [NEW] `modules/vpn_server/compute.tf`
- **Elastic IP (EIP):** Provisions a static public IP for the VPN.
- **Auto Scaling Group (ASG):** Configures an ASG with Min: 1, Max: 1, Desired: 1 for active/passive self-healing.
- **WireGuard Clients:** Dynamically generates public/private keypairs for **10 clients**.

#### [NEW] `modules/vpn_server/userdata.sh`
- A bash script executed on instance boot to install WireGuard, fetch SSM keys, and configure `wg0`.
- **Installs and configures the Unified CloudWatch Agent to automatically stream local logs (`syslog` and `dmesg`) to the centralized Log Group.**

## Verification Plan

### Automated Tests
- Run `terraform fmt -check` and `terraform validate` locally to ensure code integrity.
- **Tagging Compliance Verification:** We will use a static analysis tool (like `checkov` or `tfsec`) in our CI/CD pipeline to scan the Terraform code and ensure no AWS resources are missing the mandatory tags.

### Manual Verification
1. **Apply & Boot:** Run `terraform apply -auto-approve` to spin up a single region (e.g., US East).
2. **Endpoint Persistence Check:** Verify via the AWS Console that the ASG spun up the instance and the Elastic IP was successfully associated.
3. **Self-Healing Test:** Terminate the EC2 instance manually. Wait ~3 minutes, and verify that the ASG spun up a new instance and the Elastic IP was successfully re-associated to the new instance.
7. **Observability Verification:** Verify that the CloudWatch Log Group contains recent logs, and the Dashboard displays metric data.
8. **Tagging Validation:** Use the AWS Resource Groups console to confirm all resources are properly tagged.

## Phase 2: React Web App Feature & Design Plan

Before we deploy the infrastructure, we need to map out exactly what the React Web Application will do, how it will look, and how you will interact with it. 

Here is a baseline proposal for the features and design based on standard WireGuard management.

### Proposed Features

#### 1. The Dashboard (Home View)
- A clean, data-rich table listing all currently active VPN clients.
- **Columns:** Client Name (e.g., "Work Laptop"), IP Address (e.g., `10.8.0.100`), Public Key (truncated), and Creation Date.
- **Actions:** A "Revoke/Delete" button next to each client to instantly ban them from the VPN (removes them from DynamoDB).

#### 2. Client Generation Workflow
- A prominent "Issue New Key" button.
- A simple modal asks for a **Client Name**.
- When you submit, the app instantly generates the cryptographic keys in the browser, pushes the public key to AWS, and presents you with a success screen.

#### 3. Configuration Delivery
- On the success screen, the app will display a **QR Code**. You can simply open the WireGuard app on your phone, tap "Scan from QR code", point it at your screen, and you are instantly connected.
- A **Download .conf** button for setting up laptops or desktops.
- *(Crucial Security Note: The private key is NEVER saved to AWS. Once you close the success screen, the private key is gone forever. If you lose the device, you must revoke the key and issue a new one).*

### Proposed Aesthetics
- **Framework:** React + Semantic UI (`semantic-ui-react`).
- **Theme:** Strict **Dark Mode** (`<Segment inverted>`, `<Menu inverted>`, `<Table inverted>`).
- **Styling:** We will override standard Semantic UI variables to inject "Glassmorphic" elements (semi-transparent blurred backgrounds), vibrant accent colors (e.g., Neon Cyan or Purple gradients), and modern typography (like the `Inter` font) to make it feel extremely premium and cutting-edge.

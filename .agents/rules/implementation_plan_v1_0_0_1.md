# Terraform Implementation: AWS WireGuard VPN (v1.0.0.1)

## Phase 3: Development Environment & CI/CD Pipeline

To ensure a safe and cost-effective workflow, we will separate the infrastructure into independent `dev` and `prod` environments and automate deployments using GitHub Actions.

### Proposed Implementation: Terraform Workspaces

1. **State Isolation:** We will utilize **Terraform Workspaces** (`dev` and `prod`). Workspaces allow us to use the same configuration files but maintain completely isolated state files in the S3 backend.
2. **Resource Naming:** The active workspace (`terraform.workspace`) will be dynamically injected into resource names and tags (e.g., `vpn-api-${terraform.workspace}-us-east-1`). This guarantees that dev and prod resources will not collide within the same AWS account.
3. **Cost-Saving Toggles:** We will introduce environment-specific variable files (`env/dev.tfvars` and `env/prod.tfvars`). To save costs, the `dev.tfvars` can have the VPN EC2 instances toggled `OFF` (`deploy_instances = false`) when active development is not occurring, minimizing idle compute costs to near-zero.

### Proposed Implementation: GitHub Actions CI/CD

1. **Secure Authentication:** The pipeline will authenticate with AWS securely using **OpenID Connect (OIDC)**, eliminating the need for long-lived access keys in GitHub Secrets.
2. **Automated Dev Deployment:** Whenever code is merged or committed to the `main` branch, a GitHub Action workflow is automatically triggered.
   - It will select the `dev` Terraform workspace.
   - It will execute `terraform apply -auto-approve -var-file="env/dev.tfvars"`.
   - It will build and sync the React Web App to the `dev` S3 bucket.
3. **Production Gating:** After the `dev` deployment succeeds, the workflow will **pause**. We will configure a GitHub Environment Protection rule that requires explicit, manual approval before proceeding.
4. **Automated Prod Deployment:** Once the changes in the `dev` environment are manually validated, the user clicks "Approve" in the GitHub UI. The workflow resumes:
   - It selects the `prod` Terraform workspace.
   - It executes `terraform apply -auto-approve -var-file="env/prod.tfvars"`.
   - It builds and syncs the React Web App to the `prod` S3 bucket.

### Open Questions for the User
> [!WARNING]
> Because we are currently managing the production infrastructure directly in the default workspace, migrating to a `prod` workspace will require safely migrating the Terraform state. Additionally, we will need to update the AWS IAM OIDC Provider to trust your GitHub repository. Does this CI/CD architecture align with what you are looking for?

---
name: cicd_strategy
description: CI/CD Pipeline strategy and GitHub Actions rules
trigger: always_on
---

# CI/CD Pipeline Strategy (GitHub Actions)

To ensure infrastructure deployments are robust, auditable, and automated, this project will utilize **GitHub Actions** for Continuous Integration and Continuous Deployment (CI/CD) of the Terraform code.

## 1. Secure AWS Authentication (OIDC)
Just as we avoided using permanent Access Keys for local development, we will avoid storing permanent AWS credentials in GitHub Secrets. 

Instead, the pipeline will use **OpenID Connect (OIDC)**. 
- GitHub Actions will authenticate directly with AWS via an OIDC Identity Provider.
- AWS will dynamically grant the GitHub runner a short-lived, temporary session token tied to a specific IAM Role.
- **Benefit:** Maximum security. No secrets to rotate, and no risk of leaked credentials.

## 2. CI Workflow: Pull Requests (Validation & Planning)
Whenever a developer opens a Pull Request (PR) against the `main` branch, the CI workflow triggers. Its goal is to validate the code and preview changes before they happen.

**Steps:**
1. **Formatting:** Runs `terraform fmt -check` to ensure code style consistency.
2. **Validation:** Runs `terraform validate` to catch syntax or configuration errors.
3. **Security Linting:** Runs tools like `tfsec` or `tflint` to scan for security vulnerabilities or bad practices.
4. **Plan Generation:** Runs `terraform plan` to calculate what AWS resources will be created, modified, or destroyed.
5. **PR Commenting:** The workflow automatically takes the output of the `terraform plan` and posts it as a comment on the Pull Request. This allows reviewers to clearly see the blast radius of the changes before clicking "Merge".

## 3. CD Workflow: Main Branch (Deployment)
Whenever a Pull Request is successfully merged into the `main` branch, the CD workflow triggers to deploy the infrastructure.

**Steps:**
1. **Checkout & Auth:** Checks out the code and authenticates to AWS via OIDC.
2. **Apply:** Runs `terraform apply -auto-approve` using the remote S3/DynamoDB backend.
3. **Notification:** (Optional) Sends a success or failure notification alerting the team that the VPN infrastructure has been updated.

## Summary
By separating the `plan` (validation) phase from the `apply` (deployment) phase, we ensure that no infrastructure changes happen by surprise. Every change requires a Pull Request, a successful automated plan, and a manual merge.

# WireGuard VPN Server (AWS)

A highly available, cost-optimized WireGuard VPN server deployed on AWS via Terraform.

## Documentation Reference
- [Architecture & Design](./.agents/rules/architecture.md)
- [Project Goal & Scope](./.agents/rules/goal.md)
- [Cost & Budgets](./.agents/rules/cost.md)
- [Observability & Troubleshooting](./.agents/rules/observability.md)
- [CI/CD Strategy](./.agents/rules/cicd.md)
- [AWS Initial Setup Guide](./.agents/rules/aws_setup_guide.md)

## Development

### 1. Authenticate with AWS (Daily Workflow)
This project uses AWS IAM Identity Center (SSO) to avoid storing long-lived, plaintext access keys on your machine. 

Before running any Terraform commands locally, you must authenticate your terminal with your specific SSO profile.

```bash
# Log in to AWS via your browser to get temporary credentials
aws sso login --profile <your-sso-profile-name>

# Export the profile so Terraform automatically uses it
export AWS_PROFILE="<your-sso-profile-name>"
```

To verify that your authentication was successful, run:
```bash
aws sts get-caller-identity
```
*(You should receive a JSON response showing your Account ID and the AssumedRole)*

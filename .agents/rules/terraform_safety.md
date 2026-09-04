---
name: terraform_safety
description: Restrictions around running Terraform commands
trigger: always_on
---

# Terraform Safety Rules

1. **No Automated Application:** An agent must NEVER execute `terraform apply` or `terraform destroy` without explicit, prior human approval. 
2. **Planning is Safe:** Running `terraform plan`, `terraform init`, `terraform fmt`, and `terraform validate` is perfectly safe and encouraged to validate code correctness, but the actual execution of infrastructure changes must be manually greenlit by the user.

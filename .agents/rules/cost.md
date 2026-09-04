---
name: cost_management
description: Cost management guidelines and AWS budget alerts
trigger: always_on
---

# Cost Documentation

All prices below are `us-east-1` on-demand list prices. They are a planning aid, not a
quote — check the AWS pricing pages for your region before relying on them.

## What Actually Bills

Only three resources cost money on a per-hour basis. Everything else is either free or
priced per-request at volumes a personal VPN never reaches.

| Component | How it bills | Rate |
| :--- | :--- | :--- |
| **EC2 instance** | Per second while running | `t3.micro` ~$0.0104/hr, `t3.nano` ~$0.0052/hr |
| **EBS root volume** | Per GB-month provisioned | ~$0.08 per GB-month (gp3) |
| **Elastic IP** | Per hour, allocated or not | $0.005/hr per public IPv4 |
| **Outbound data transfer** | Per GB out to the internet | $0.09/GB after the first 100 GB/month |

The Elastic IP is the one to watch: AWS bills it whether or not it is attached to a
running instance, which is why disabling a region must release it rather than leave it
allocated.

## Free or Effectively Free

| Component | Why it rounds to zero |
| :--- | :--- |
| VPC, subnet, IGW, route tables, security groups | No charge |
| **Cognito** | One admin user is far below the free monthly-active-user allowance |
| **API Gateway** (HTTP API) | $1.00/million requests; admin usage is a handful per session |
| **Lambda** | 1M requests and 400,000 GB-seconds free every month, permanently |
| **DynamoDB** (on-demand) | 25 GB storage free; the instance sync scans every 10 min (~4,300/month), well under a cent |
| **CloudWatch Logs** | 5 GB/month ingestion free; 30-day retention keeps stored volume tiny |
| **CloudWatch dashboard** | First 3 dashboards free — see the caveat below |
| **CloudWatch custom metrics** | The agent publishes `mem_used_percent`; the first 10 custom metrics are free |
| **S3** (web app + state) | A few MB of static assets and state; pennies per month at most |
| **SSM Parameter Store** | Standard-tier parameters are free |
| **AWS Budgets** | First two budgets are free |
| **EBS encryption** | The AWS-managed `aws/ebs` key carries no monthly key charge |

**Dashboard caveat:** each active region provisions its own CloudWatch dashboard. Past
three dashboards in the account, AWS charges $3.00/month each — enough to matter at this
budget, so factor it in beyond two regions.

## Monthly Estimates (one region, 730 hours)

| Scenario | EC2 | EBS (8 GB gp3) | Elastic IP | **Total** |
| :--- | ---: | ---: | ---: | ---: |
| `t3.micro` (default) | $7.59 | $0.64 | $3.65 | **~$11.88** |
| `t3.nano` (cheapest) | $3.80 | $0.64 | $3.65 | **~$8.09** |
| Region disabled | $0.00 | $0.00 | $0.00 | **$0.00** |

Excludes outbound data transfer, which is usage-dependent — the first 100 GB/month is
free, and every GB after that is $0.09.

`instance_type` and `root_volume_size` are variables, so moving between the first two
rows is a one-line change in `terraform.tfvars` followed by an instance replacement.

Accounts still inside the legacy 12-month AWS Free Tier get 750 hours/month of
`t3.micro`, 30 GB of EBS, and 750 hours of public IPv4, which brings year-one cost close
to zero. Accounts opened after the 2025 free-tier change receive credits instead. Confirm
against the current AWS Free Tier page rather than assuming either.

## Multi-Region Cost

Cost scales linearly per active region — there is no shared always-on component, no load
balancer, and no global accelerator. Two regions running `t3.nano` cost roughly $16/month;
turning one off returns to roughly $8/month on the next `terraform apply`.

## Budget Alerts

A global **AWS Budget** is provisioned by Terraform alongside the infrastructure.

- **Scope:** filters on the `user:Project$vpn-server` cost allocation tag, so it tracks the
  VPN across every region and ignores unrelated workloads in the account.
- **Threshold:** $25.00/month, alerting on both **actual** and **forecasted** spend at 100%.
- **Delivery:** email to `budget_alert_email`, injected via a gitignored `terraform.tfvars`
  so no personal address is committed.
- **Cost:** $0.00 — AWS provides the first two budgets free.

The threshold is deliberately well above the ~$12 baseline: its job is to catch runaway
outbound data transfer, not to alarm on normal operation.

> Cost allocation tags must be activated once in **Billing → Cost allocation tags** before
> the `Project` filter returns data. Until then the budget reports $0 regardless of spend.

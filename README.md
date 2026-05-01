# Terraform AWS Automated Access Review

A Terraform port of [ajy0127/aws_automated_access_review](https://github.com/ajy0127/aws_automated_access_review) with policy-as-code guardrails using OPA/Conftest.

## What this project does

Automated AWS security posture review delivered to your inbox on a schedule. The Lambda pulls findings from IAM, Security Hub, IAM Access Analyzer, CloudTrail, and Organizations SCPs, generates an AI-narrative summary via Amazon Bedrock, writes a CSV to S3, and emails the report via SES.

## What this fork adds

| Layer | Original | This repo |
| --- | --- | --- |
| Infrastructure as Code | CloudFormation | **Terraform** |
| State management | CFN-managed | **S3 backend with native locking** |
| Compliance enforcement | Manual review | **OPA/Rego policy gate** (3 controls) |
| Deploy workflow | Two-step (deploy stack, update Lambda) | **Single `terraform apply`** |

## Repository layout

```
.
├── terraform/        Terraform configuration (S3, IAM, Lambda, EventBridge)
├── policy/           OPA/Rego policies enforcing NIST 800-53 / CMMC controls
├── scripts/          Wrapper scripts for deploy + manual report invocation
├── src/lambda/       Python Lambda code (unchanged from upstream)
└── README.md
```

## Compliance controls enforced

Every `terraform plan` is evaluated against three OPA policies before apply:

| Policy | Control mapping |
| --- | --- |
| `s3_public_access.rego` | NIST 800-53 AC-3, SC-7 • CMMC AC.L2-3.1.3 |
| `iam_no_wildcard.rego` | NIST 800-53 AC-6 • CMMC AC.L2-3.1.5 |
| `s3_encryption.rego` | NIST 800-53 SC-28 • CMMC SC.L2-3.13.16 |

If any policy fails, `terraform apply` never runs. The control documentation IS the policy file.

## Prerequisites

- AWS CLI configured with credentials in the target account
- Terraform >= 1.5
- Conftest (`brew install conftest`)
- An SES-verified recipient email
- Bedrock model access granted for Anthropic Claude (Haiku 4.5 default)

## Quick start

```bash
# 1. Configure your inputs
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — set recipient_email to your SES-verified address

# 2. Deploy with the policy gate
cd ..
./scripts/tf_deploy.sh

# 3. Manually invoke the Lambda to generate a report immediately
./scripts/tf_run_report.sh
```

Email arrives within ~60 seconds.

## State backend

Terraform state lives in S3 with native locking (`use_lockfile = true`, requires Terraform 1.10+). Update the `backend "s3"` block in `terraform/main.tf` with your own state bucket name before running `terraform init`.

## License

MIT — see [LICENSE](LICENSE) for details. Forked from work by [AJ Yawn](https://github.com/ajy0127).

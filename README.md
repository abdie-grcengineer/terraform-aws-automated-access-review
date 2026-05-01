# AWS Automated Access Review

Continuous AWS security posture assessment with policy-as-code guardrails. Built for GRC teams who need audit-ready evidence without standing up a SIEM or spending weeks on a custom pipeline.

The system runs on a schedule, pulls findings from native AWS security services, summarizes them with an LLM, archives a CSV in S3, and delivers the report by email. Every infrastructure change is validated against NIST 800-53 / CMMC controls before deploy — misconfigurations get blocked at the IaC layer, not at the next quarterly audit.

## Why this is GRC engineering

Traditional GRC programs document controls in Word, evidence them with screenshots, and audit them quarterly. By that point, drift has already happened.

GRC Engineering inverts the model: **the control is the code.** Infrastructure-as-code defines the system, policy-as-code enforces the rules, and CI runs the gate on every change. There is no separate "compliance team" reviewing things after the fact — compliance is implemented in the same pipeline that ships the system.

This project is a working demonstration of that model:

- **Infrastructure as Code (Terraform)** — every AWS resource is declared in version-controlled files. State is reproducible. There is no "click-ops" step that bypasses review. Maps to NIST 800-53 **CM-2 (Baseline Configuration)** and **CM-3 (Configuration Change Control)**.
- **Policy as Code (OPA / Rego)** — security controls are encoded as rules that run before deploy. A misconfiguration cannot reach AWS because the gate fails the build first. Maps to **AC-3, AC-6, SC-7, SC-28** depending on which policy fires.
- **Audit Evidence by Construction** — every Terraform plan is archived. Every CI run is logged. Every Lambda execution is recorded in CloudTrail. The auditor's question "show me what changed and when" has a one-command answer. Maps to **AU-2 (Audit Events)** and **AU-12 (Audit Generation)**.
- **Federated Authentication (OIDC)** — CI assumes an IAM role via short-lived tokens. No long-lived credentials in any system. Maps to **IA-2(8) (Replay-Resistant Authentication)** and **IA-5 (Authenticator Management)**.
- **Least Privilege at Every Layer** — the Lambda execution role is scoped to the actions it actually needs. The CI role is scoped to the resources it manages. Both are continuously enforced by the OPA wildcard policy. Maps to **AC-6 (Least Privilege)**.

Translated to CMMC: **AC.L2-3.1.3, AC.L2-3.1.5, AU.L2-3.3.1, CM.L2-3.4.2, IA.L2-3.5.3, SC.L2-3.13.16**.

## Architecture

The system is **fully serverless**. There are no EC2 instances, no containers to patch, no scheduling daemons to monitor. Every component is event-driven and pay-per-execution.

```
                                ┌─────────────────────────────────────────┐
                                │  Native AWS Security Services           │
                                │  ─ IAM (users, roles, MFA, keys)        │
                                │  ─ Security Hub (findings)              │
                                │  ─ IAM Access Analyzer (external access)│
                                │  ─ CloudTrail (audit log config)        │
                                │  ─ Organizations (SCPs)                 │
                                └─────────────┬───────────────────────────┘
                                              │
   ┌─────────────────────┐                    │ read-only
   │ EventBridge         │                    │
   │ rate(30 days)       │ invoke             ▼
   │                     ├──────────────►┌─────────────────┐
   └─────────────────────┘               │ Lambda          │
                                         │ (Python 3.11)   │
   ┌─────────────────────┐               │ 512 MB · 5 min  │
   │ Manual invoke       │ invoke        │                 │
   │ (run_report.sh)     ├──────────────►│                 │
   └─────────────────────┘               └────┬──┬─────┬───┘
                                              │  │     │
                       ┌──────────────────────┘  │     └────────────────────┐
                       │                         │                          │
                       ▼                         ▼                          ▼
            ┌─────────────────────┐   ┌────────────────────┐   ┌──────────────────────┐
            │ Bedrock             │   │ S3 (encrypted,     │   │ SES                  │
            │ Claude Haiku 4.5    │   │ versioned, 90-day  │   │ Email delivery to    │
            │ (narrative summary) │   │ lifecycle)         │   │ verified recipients  │
            └─────────────────────┘   └────────────────────┘   └──────────────────────┘
```

**Why serverless matters for GRC:**

- **No infrastructure to harden, patch, or attest.** The auditor scope shrinks from "how do you secure your servers?" to "what does the function do, and what can it access?" — both answered by reading the IAM policy in `terraform/iam.tf`.
- **No persistent compute means no persistent attack surface.** The Lambda execution context exists for the duration of one report, then disappears.
- **Pay-per-execution.** Running a monthly access review costs ~$1/month in `us-east-1`. There is no idle infrastructure burning budget.
- **Native AWS integration.** EventBridge invokes Lambda directly. Lambda calls Bedrock, S3, and SES through SDK clients that authenticate via the execution role. No glue code, no API gateways, no shims.
- **CloudTrail captures everything.** Every Lambda invocation, every Bedrock call, every S3 PUT — all logged automatically. Audit evidence is generated by AWS, not by the application.

## How it works

A scheduled EventBridge rule invokes the Lambda every 30 days (configurable). The function inspects native AWS security services for findings, generates a plain-English executive summary via Amazon Bedrock, writes a timestamped CSV report to S3 with a 90-day retention lifecycle, and emails the report via SES.

## Tech stack

| Layer | Choice | Why |
| --- | --- | --- |
| Infrastructure as Code | **Terraform** (>= 1.10) | Declarative, version-controlled, reproducible state |
| State management | **S3 backend** with `use_lockfile = true` | Encrypted, versioned, S3-native locking — no DynamoDB required |
| Policy as Code | **OPA / Conftest** with Rego | Industry standard (CNCF graduated); rules are testable and version-controlled |
| CI/CD | **GitHub Actions** | Native PR integration, OIDC support, free for public repos |
| Cloud auth (CI) | **OIDC federation** | Short-lived tokens, no long-lived credentials in GitHub Secrets |
| Compute | **AWS Lambda** (Python 3.11) | Serverless, pay-per-execution, no patching |
| Scheduler | **Amazon EventBridge** | Native AWS, no cron daemon to maintain |
| AI summary | **Amazon Bedrock** (Claude Haiku 4.5) | Right-sized model for summarization workload |
| Storage | **Amazon S3** with SSE-AES256, versioning, 90-day lifecycle | Encrypted at rest, audit-evidence-ready |
| Email delivery | **Amazon SES** | Native, scales without ops |
| Identity provider for findings | **IAM, Security Hub, Access Analyzer, CloudTrail, Organizations** | Native AWS sources — no third-party scanners |

## Compliance controls enforced

Three OPA policies are evaluated against every Terraform plan. If any policy fails, the deploy is blocked.

| Policy | Control mapping |
| --- | --- |
| `policy/s3_public_access.rego` | NIST 800-53 AC-3, SC-7 • CMMC AC.L2-3.1.3 |
| `policy/iam_no_wildcard.rego` | NIST 800-53 AC-6 • CMMC AC.L2-3.1.5 |
| `policy/s3_encryption.rego` | NIST 800-53 SC-28 • CMMC SC.L2-3.13.16 |

The control documentation is the policy file. New policies are added as `.rego` files under `policy/` and picked up automatically by the deploy gate.

## Repository layout

```
.
├── terraform/                 IaC for S3, IAM, Lambda, EventBridge
│   ├── main.tf                Provider, S3 backend, account lookup
│   ├── variables.tf           Inputs (email, schedule, model, region)
│   ├── s3.tf                  Report bucket + lifecycle + encryption
│   ├── iam.tf                 Lambda execution role (least privilege)
│   ├── lambda.tf              Function + EventBridge schedule
│   └── outputs.tf             Outputs for downstream automation
├── policy/                    OPA/Rego policies (NIST/CMMC controls)
├── scripts/
│   ├── tf_deploy.sh           Plan → policy gate → apply
│   ├── tf_run_report.sh       Manually invoke the Lambda
│   └── bootstrap_github_oidc.sh   Set up OIDC trust for CI
├── src/lambda/                Python Lambda implementation
└── .github/workflows/         CI pipeline (plan + policy gate + apply)
```

## Architecture decisions

**S3 remote backend with native locking.** State lives in an encrypted, versioned S3 bucket with `use_lockfile = true` (Terraform 1.10+). No DynamoDB lock table required. State is sensitive — it gets the same protection as audit evidence.

**Single-step deploy.** The Lambda code is packaged at plan time via the `archive_file` data source. Editing any Python file changes the source hash, which triggers a redeploy on the next `terraform apply`. No manual `update-function-code` step.

**Provider-level default tags.** Every resource is tagged with `Project` and `ManagedBy = "Terraform"` automatically. Provenance is enforced by construction, not by reviewer discipline.

**OIDC for CI authentication.** GitHub Actions assumes an IAM role via OIDC short-lived tokens. No long-lived AWS credentials are stored in GitHub Secrets.

## Prerequisites

- AWS account with IAM, S3, Lambda, EventBridge, Bedrock, SES permissions
- AWS CLI v2 configured for the target account
- Terraform >= 1.10
- [Conftest](https://www.conftest.dev/) (`brew install conftest`)
- SES-verified recipient email
- Bedrock model access granted for the configured Claude model

## Quick start

```bash
# 1. Configure your inputs
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — set recipient_email to your SES-verified address

# 2. Bootstrap the remote state backend (one-time)
#    Create an S3 bucket, then update the backend block with your bucket name.

# 3. Initialize Terraform
terraform init

# 4. Deploy with the policy gate
cd ..
./scripts/tf_deploy.sh

# 5. Trigger an immediate report
./scripts/tf_run_report.sh
```

The first invocation generates a CSV in the report bucket and emails the recipient within ~60 seconds.

## CI/CD

The GitHub Actions workflow at `.github/workflows/terraform.yml` runs on every pull request and every push to `main`:

1. Checkout
2. Configure AWS credentials via OIDC
3. `terraform init` and `terraform plan -out=tfplan`
4. Conftest evaluates all policies under `policy/`
5. The plan artifact is uploaded for audit retention
6. On push to `main` only: `terraform apply tfplan`

A failing policy fails the workflow before apply runs. PRs cannot be merged with a red check unless the branch protection rules are bypassed.

## Cost

Approximately $1/month in `us-east-1` for a typical account. Bedrock is the dominant cost; Haiku 4.5 keeps it minimal. Lambda execution typically completes in 2-3 minutes.

## License

MIT — see [LICENSE](LICENSE).

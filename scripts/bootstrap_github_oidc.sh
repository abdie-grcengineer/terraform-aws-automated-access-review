#!/bin/bash
set -e

# Bootstrap GitHub Actions OIDC trust to AWS.
# Creates: OIDC provider + IAM role with trust policy + permissions policy.
# Run once per AWS account.

GITHUB_OWNER="abdie-grcengineer"
GITHUB_REPO="terraform-aws-automated-access-review"
ROLE_NAME="github-actions-terraform-aws-access-review"
REGION="us-east-1"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

echo "Account: $ACCOUNT_ID"
echo "Repo:    $GITHUB_OWNER/$GITHUB_REPO"
echo "Role:    $ROLE_NAME"
echo ""

# Step 1: Create OIDC provider (skip if it already exists)
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" >/dev/null 2>&1; then
  echo "[1/3] OIDC provider already exists, skipping creation"
else
  echo "[1/3] Creating OIDC provider for token.actions.githubusercontent.com"
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
    >/dev/null
fi

# Step 2: Build trust policy scoped to this specific repo
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_OWNER}/${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF
)

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "[2/3] Role already exists, updating trust policy"
  aws iam update-assume-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-document "$TRUST_POLICY"
else
  echo "[2/3] Creating role $ROLE_NAME"
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --description "GitHub Actions OIDC role for terraform-aws-automated-access-review" \
    >/dev/null
fi

# Step 3: Attach permissions policies (broad managed policies for demo speed)
echo "[3/3] Attaching permissions policies"
for policy in \
  arn:aws:iam::aws:policy/AmazonS3FullAccess \
  arn:aws:iam::aws:policy/IAMFullAccess \
  arn:aws:iam::aws:policy/AWSLambda_FullAccess \
  arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess; do
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$policy"
done

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query "Role.Arn" --output text)

echo ""
echo "========================================"
echo "Done. Role ARN:"
echo "  $ROLE_ARN"
echo ""
echo "Add this as a GitHub repo secret named AWS_ROLE_ARN:"
echo "  gh secret set AWS_ROLE_ARN --body \"$ROLE_ARN\""
echo "========================================"

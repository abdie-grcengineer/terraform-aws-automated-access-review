#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

if [ ! -d "$TERRAFORM_DIR/.terraform" ]; then
  echo "Error: $TERRAFORM_DIR is not initialized. Run 'terraform init' first."
  exit 1
fi

FUNCTION_NAME=$(terraform -chdir="$TERRAFORM_DIR" output -raw lambda_function_name 2>/dev/null)

if [ -z "$FUNCTION_NAME" ]; then
  echo "Error: Could not read lambda_function_name output. Has 'terraform apply' run yet?"
  exit 1
fi

REGION=$(terraform -chdir="$TERRAFORM_DIR" output -raw aws_region 2>/dev/null || echo "us-east-1")

echo "Invoking $FUNCTION_NAME..."
RESPONSE_FILE=$(mktemp)

aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --payload '{}' \
  --cli-binary-format raw-in-base64-out \
  "$RESPONSE_FILE" >/dev/null

echo ""
echo "Response:"
cat "$RESPONSE_FILE"
echo ""
echo ""
echo "CloudWatch logs:"
echo "  https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#logsV2:log-groups/log-group/%2Faws%2Flambda%2F${FUNCTION_NAME}"
echo ""

rm -f "$RESPONSE_FILE"

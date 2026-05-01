variable "recipient_email" {
  description = "SES-verified email address that receives the access review report"
  type        = string
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "schedule_expression" {
  description = "EventBridge schedule for the Lambda (e.g. rate(30 days), cron(...))"
  type        = string
  default     = "rate(30 days)"
}

variable "report_bucket_name" {
  description = "Name for the S3 report bucket. Leave empty to let Terraform generate one"
  type        = string
  default     = ""
}

variable "bedrock_model_id" {
  description = "Bedrock model or inference profile ID for the AI narrative"
  type        = string
  default     = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "name_prefix" {
  description = "Prefix applied to resource names (replaces $${AWS::StackName} from the CFN template)"
  type        = string
  default     = "aws-access-review"
}
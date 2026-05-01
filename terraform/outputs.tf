output "report_bucket_name" {
  description = "Name of the S3 bucket storing access review reports"
  value       = aws_s3_bucket.report.id
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function performing access reviews"
  value       = aws_lambda_function.access_review.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function (use this to invoke it manually)"
  value       = aws_lambda_function.access_review.function_name
}

output "scheduled_rule_arn" {
  description = "ARN of the EventBridge rule for scheduled execution"
  value       = aws_cloudwatch_event_rule.schedule.arn
}

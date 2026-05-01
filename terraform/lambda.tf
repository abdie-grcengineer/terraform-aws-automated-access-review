data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/lambda"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "access_review" {
  function_name = "${var.name_prefix}-access-review"
  role          = aws_iam_role.access_review.arn

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  handler     = "index.handler"
  runtime     = "python3.11"
  timeout     = 300
  memory_size = 512

  environment {
    variables = {
      REPORT_BUCKET    = aws_s3_bucket.report.id
      RECIPIENT_EMAIL  = var.recipient_email
      BEDROCK_MODEL_ID = var.bedrock_model_id
    }
  }

  depends_on = [
    aws_iam_role_policy.access_review,
    aws_iam_role_policy_attachment.basic_execution,
  ]
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.name_prefix}-schedule"
  description         = "Scheduled rule for AWS Access Review"
  schedule_expression = var.schedule_expression
  state               = "ENABLED"
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "AccessReviewTarget"
  arn       = aws_lambda_function.access_review.arn
}

resource "aws_lambda_permission" "events" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.access_review.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

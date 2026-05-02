resource "aws_iam_role" "access_review" {
  name = "${var.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.access_review.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "access_review" {
  name = "AccessReviewPermissions"
  role = aws_iam_role.access_review.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3ReportBucketAccess"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      },
      {
        Sid    = "IAMReadOnly"
        Effect = "Allow"
        Action = [
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:GetUser",
          "iam:GetUserPolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListAttachedUserPolicies",
          "iam:ListPolicies",
          "iam:ListRolePolicies",
          "iam:ListRoles",
          "iam:ListUserPolicies",
          "iam:ListUsers",
          "iam:GetLoginProfile",
          "iam:ListMFADevices",
          "iam:ListAccessKeys",
          "iam:GetAccountPasswordPolicy",
        ]
        Resource = "*"
      },
      {
        Sid    = "OrganizationsRead"
        Effect = "Allow"
        Action = [
          "organizations:DescribeOrganization",
          "organizations:ListPolicies",
          "organizations:DescribePolicy",
          "organizations:ListTargetsForPolicy",
          "organizations:ListRoots",
        ]
        Resource = "*"
      },
      {
        Sid    = "SecurityHubRead"
        Effect = "Allow"
        Action = [
          "securityhub:GetFindings",
          "securityhub:GetInsights",
          "securityhub:GetEnabledStandards",
        ]
        Resource = "*"
      },
      {
        Sid    = "AccessAnalyzerRead"
        Effect = "Allow"
        Action = [
          "access-analyzer:ListAnalyzers",
          "access-analyzer:ListFindings",
          "access-analyzer:GetFinding",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudTrailRead"
        Effect = "Allow"
        Action = [
          "cloudtrail:LookupEvents",
          "cloudtrail:DescribeTrails",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:GetEventSelectors",
        ]
        Resource = "*"
      },
      {
        Sid      = "BedrockInvoke"
        Effect   = "Allow"
        Action   = "bedrock:InvokeModel"
        Resource = "*"
      },
      {
        Sid    = "SESSend"
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:VerifyEmailIdentity",
          "ses:GetIdentityVerificationAttributes",
        ]
        Resource = "*"
      },
    ]
  })
}

# IAM Policy to allow reading from SSM Parameter Store
resource "aws_iam_policy" "ssm_read_policy" {
  name = "${var.app_name}-ssm-read-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.app_name}/google-maps-api-key"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.app_name}/google-maps-api-sv-key"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_read_role_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ssm_read_policy.arn
}

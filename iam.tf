# IAM Role and Policy for AWS Lambda to manage ALB rules
resource "aws_iam_role" "lambda_role" {
  name = "${var.app_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}



resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.app_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# SNSがCloudWatch Logsに書き込むためのIAMロール
resource "aws_iam_role" "sns_cloudwatch_role" {
  name = "${var.app_name}-sns-cloudwatch-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
      }
    ]
  })
}

# SNSにCloudWatch Logsへの書き込み権限を与えるIAMポリシー
resource "aws_iam_role_policy" "sns_cloudwatch_policy" {
  name = "${var.app_name}-sns-cloudwatch-policy"
  role = aws_iam_role.sns_cloudwatch_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*" # より厳密に指定することも可能
      }
    ]
  })
}

# IAM Role for Lambda to generate shadow data and interact with S3
# S3アクセス権限ポリシー
resource "aws_iam_policy" "s3_access_policy" {
  name        = "lambda_s3_shadow_access"
  description = "Allows Lambda to read input and write output to specific S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "s3:GetObject",
        Resource = "${aws_s3_bucket.input_bucket.arn}/*",
      },
#      {
#        Effect   = "Allow",
#        Action   = "s3:PutObject",
#        Resource = "${aws_s3_bucket.output_bucket.arn}/*",
#      },
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Lambda実行ロールとポリシー（ECSを更新する権限）
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-ecs-scheduler-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_ecs_policy" {
  name = "lambda-ecs-scheduler-policy"
  role = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ecs:UpdateService",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}
#
## ----------------------------------------------------------------------
## 1. Step Functions 実行IAMロールとポリシー
## ----------------------------------------------------------------------
#
#resource "aws_iam_role" "sfn_exec_role" {
#  name = "${var.app_name}-sfn-exec-role"
#
#  assume_role_policy = jsonencode({
#    Version = "2012-10-17"
#    Statement = [
#      {
#        Action = "sts:AssumeRole"
#        Effect = "Allow"
#        Principal = {
#          Service = "states.amazonaws.com"
#        }
#      }
#    ]
#  })
#}
##
#resource "aws_iam_policy" "sfn_policy" {
#  name        = "${var.app_name}-sfn-policy"
#  description = "Allows SFN to invoke Lambda and write to CloudWatch Logs"
#  policy      = jsonencode({
#    Version = "2012-10-17"
#    Statement = [
#      {
#        Effect   = "Allow"
#        Action   = "lambda:InvokeFunction"
#        Resource = aws_lambda_function.shadow_generator.arn # ShadowGeneratorFunctionのARN
#      },
#      {
#        Effect   = "Allow"
#        Action   = [
#          "logs:CreateLogGroup",
#          "logs:CreateLogStream",
#          "logs:PutLogEvents"
#        ]
#        # Step Functions用のロググループに限定
#        Resource = "arn:aws:logs:*:*:log-group:/aws/step-functions/${var.app_name}-ShadowDataPipeline:*" 
#      }
#    ]
#  })
#}
#
#resource "aws_iam_role_policy_attachment" "sfn_policy_attach" {
#  role       = aws_iam_role.sfn_exec_role.name
#  policy_arn = aws_iam_policy.sfn_policy.arn
#}
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

## ----------------------------------------------------------------------
## 2. EC2操作 & VPC接続用 IAMポリシー
## ----------------------------------------------------------------------

# LambdaがEC2を起動/停止し、VPCに接続するためのポリシー
resource "aws_iam_policy" "lambda_ec2_vpc_policy" {
  name        = "lambda-ec2-vpc-access-policy"
  description = "Allows Lambda to start/stop EC2 and manage ENIs for VPC access."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # 1. EC2インスタンスの起動/停止権限
      {
        Effect   = "Allow",
        Action   = [
          "ec2:StartInstances",
          "ec2:StopInstances"
        ],
        Resource = "*" # インスタンスIDを限定することも可能
      },
      # 2. LambdaをVPCに配置するために必須のENI管理権限
      {
        Effect   = "Allow",
        Action   = [
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces"
        ],
        Resource = "*"
      },
      # 3. CloudWatch Logsへの書き込み権限 (既存のログ権限の確認のため再度追加)
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

# 作成したポリシーを既存のLambda実行ロールにアタッチ
resource "aws_iam_role_policy_attachment" "ec2_vpc_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_ec2_vpc_policy.arn
}
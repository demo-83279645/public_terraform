# ----------------------------------------------------------------------
# 1. S3バケット (入力・出力)
# ----------------------------------------------------------------------
# S3バケットへの読み取り権限を定義するIAMポリシーを作成
resource "aws_iam_policy" "s3_read_access_policy" {
  name        = "${var.app_name}-s3-read-access-policy"
  description = "Allows read access to S3 buckets for the application"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.input_bucket.arn,
          "${aws_s3_bucket.input_bucket.arn}/*"
        ]
      }
    ]
  })
}

# 作成したポリシーをECSタスクロールにアタッチ
resource "aws_iam_role_policy_attachment" "ecs_task_s3_read_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_read_access_policy.arn
}

resource "aws_s3_bucket" "input_bucket" {
  bucket = "${var.app_name}-shadow-data-input"
}

## 2. S3ゲートウェイエンドポイント (EC2からS3へのプライベートアクセス)
resource "aws_vpc_endpoint" "s3_gateway" {
  # VPC ID
  vpc_id = aws_vpc.main.id

  # サービス名 (リージョン名はご自身の環境に合わせて修正してください。例: ap-northeast-1)
  service_name = "com.amazonaws.ap-northeast-1.s3"

  # ゲートウェイエンドポイントタイプ
  vpc_endpoint_type = "Gateway"

  # ⚠️ 修正点: aws_route_table.private のIDを全て関連付けます
  # aws_route_table.private は単一リソースとして定義されているため、IDを直接指定
  route_table_ids = [aws_route_table.private.id] 

  # S3へのアクセスを許可するポリシー
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # IAMロールでアクセスを制御するため、Principalはワイルドカード(*)で許可
        Effect    = "Allow"
        Principal = "*" 
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject" # EC2のPythonスクリプトによる書き込み操作のため追加
        ]
        # アクセスを aws_s3_bucket.input_bucket のみに制限
        Resource = [
          aws_s3_bucket.input_bucket.arn,
          "${aws_s3_bucket.input_bucket.arn}/*"
        ]
      },
    ]
  })

  tags = {
    Name = "${var.app_name}-s3-gateway-endpoint"
  }
}
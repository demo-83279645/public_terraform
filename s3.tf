# S3 Bucket for shadow data (GeoJSON)
resource "aws_s3_bucket" "shadow_data_bucket" {
  bucket = "${var.app_name}-shadow-data"
}
# ----------------------------------------------------------------------
# 1. S3バケット (入力・出力)
# ----------------------------------------------------------------------
resource "aws_s3_bucket" "input_bucket" {
  bucket = "${var.app_name}-shadow-data-input"
}

resource "aws_s3_bucket" "output_bucket" {
  bucket = "${var.app_name}-shadow-data-output"
}

#Lambda Layer用S3バケット
resource "aws_s3_bucket" "lambda_layer_bucket" {
  bucket = "${var.app_name}-lambda-layers"
}


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
          aws_s3_bucket.shadow_data_bucket.arn,
          "${aws_s3_bucket.shadow_data_bucket.arn}/*"
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

# Layerのzipファイルをアップロードすることを前提とする
resource "aws_s3_object" "geopandas_layer_zip" {
  bucket = aws_s3_bucket.lambda_layer_bucket.id
  key    = "geopandas/lambda-deploy.zip"
  # ホスト側の geolambda/python/lambda-deploy.zip を参照
  source = "${path.module}/geopandas_layer/geolambda/python/lambda-deploy.zip"
}


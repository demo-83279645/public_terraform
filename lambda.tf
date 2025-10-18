resource "aws_sns_topic" "maintenance_notification" {
  name = "${var.app_name}-maintenance-notification"

  # SNSの配信ログを有効にするための引数を追加
  lambda_success_feedback_role_arn = aws_iam_role.sns_cloudwatch_role.arn
  lambda_failure_feedback_role_arn = aws_iam_role.sns_cloudwatch_role.arn
  lambda_success_feedback_sample_rate = 100
}

# IAM Role for Lambda function
resource "aws_lambda_function" "update_listener_rule" {
  function_name = "${var.app_name}-update-listener-rule"
  handler       = "main.handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  
  source_code_hash = filebase64sha256("lambda/main.py.zip")
  filename = "lambda/main.py.zip"

  environment {
    variables = {
      LISTENER_ARN = aws_lb_listener.https.arn
      TARGET_GROUP_ARN = aws_lb_target_group.app_tg.arn
    }
  }
}

resource "aws_lambda_permission" "allow_sns_to_call_lambda" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_listener_rule.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.maintenance_notification.arn
}

# SNS Topic Subscription for Lambda function
resource "aws_sns_topic_subscription" "maintenance_subscription" {
  topic_arn = aws_sns_topic.maintenance_notification.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.update_listener_rule.arn
}


# Lambdaコードのパッケージング (デプロイメントの準備として外部でzipを作成すること)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "src/" # main.pyとmodulesフォルダがあるディレクトリ
  output_path = "lambda_package.zip"
}

resource "aws_lambda_function" "shadow_generator" {

  function_name    = "ShadowGeneratorFunction"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "main.main" # main.py の main関数
  #runtime          = "python3.12"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_exec_role.arn
  
  # 高負荷処理のためメモリとタイムアウトを増加
  memory_size = 3072 # 3GB推奨
  timeout     = 900  # 15分 (最大値)

  # GeoLambda Layer のARNを直接指定
  layers = [
    aws_lambda_layer_version.custom_geopandas_layer.arn,
  ]
  # GeoLambdaが要求する環境変数を設定
  environment {
    variables = {
      # S3バケットは東京リージョンのものを渡す (Step Functionsから渡される想定)
      OUTPUT_BUCKET = aws_s3_bucket.output_bucket.bucket 
#      INPUT_BUCKET  = aws_s3_bucket.input_bucket.bucket
      
      # GeoLambda Layerの必須設定
      GDAL_DATA     = "/opt/share/gdal"
      PROJ_LIB      = "/opt/share/proj" # GeoLambda 2.0.0+ 向け
          }
#      INPUT_KEY     = "${var.app_name}-input_key_name"

  }
}
  
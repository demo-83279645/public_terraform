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


# EC2インスタンスを起動するLambda関数
resource "aws_lambda_function" "start_ec2_function" {
  filename      = "lambda/start_ec2.py.zip" # 適切なファイル名に変更してください
  function_name = "${var.app_name}-start-ec2-function"
  # 適切なIAM Roleを指定してください（例：EC2のStart/Stop権限を持つロール）
  role          = aws_iam_role.lambda_exec_role.arn 
  handler       = "start_ec2.lambda_handler" # 適切なハンドラ名に変更してください
  runtime       = "python3.9" 

  source_code_hash = filebase64sha256("lambda/start_ec2.py.zip")
  timeout       = 10
  
  environment {
    variables = {
      # aws_instance.app_server.*.id はIDのリストになる
      # join関数でそのリストをカンマ (,) 区切りの文字列に変換する
      INSTANCE_IDS = join(",", aws_instance.app_server.*.id) 
    }
  }
}

# EC2インスタンスを停止するLambda関数
resource "aws_lambda_function" "stop_ec2_function" {
  filename      = "lambda/stop_ec2.py.zip" # 適切なファイル名に変更してください
  function_name = "${var.app_name}-stop-ec2-function"
  # 適切なIAM Roleを指定してください（例：EC2のStart/Stop権限を持つロール）
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "stop_ec2.lambda_handler" # 適切なハンドラ名に変更してください
  runtime       = "python3.9"

  source_code_hash = filebase64sha256("lambda/stop_ec2.py.zip")
  timeout       = 10
  
  environment {
    variables = {
      # aws_instance.app_server.*.id はIDのリストになる
      # join関数でそのリストをカンマ (,) 区切りの文字列に変換する
      INSTANCE_IDS = join(",", aws_instance.app_server.*.id) 
    }
  }
  # 【★追加】このブロックを追加してLambdaをVPC内に配置
  vpc_config {
    # EC2と同じプライベートサブネットを指定
    subnet_ids         = aws_subnet.private.*.id
    # 上記で作成したLambda/エンドポイント用のセキュリティグループを指定
    security_group_ids = [aws_security_group.lambda_endpoint_sg.id] 
  }
}
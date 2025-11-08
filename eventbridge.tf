# ECSサービスを起動するLambda関数
resource "aws_lambda_function" "start_ecs_function" {
  filename      = "lambda/start_ecs.py.zip"
  function_name = "start-ecs-function"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "start_ecs.lambda_handler"
  runtime       = "python3.9"

  source_code_hash = filebase64sha256("lambda/start_ecs.py.zip")
}

# ECSサービスを停止するLambda関数
resource "aws_lambda_function" "stop_ecs_function" {
  filename      = "lambda/stop_ecs.py.zip"
  function_name = "stop-ecs-function"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "stop_ecs.lambda_handler"
  runtime       = "python3.9"

  source_code_hash = filebase64sha256("lambda/stop_ecs.py.zip")
}

# 毎日9時にECSサービスを起動するEventBridgeルール
resource "aws_cloudwatch_event_rule" "start_ecs_rule" {
  name                = "start-ecs-at-9h"
  schedule_expression = "cron(0 0 * * ? *)"
}

# 毎日21時にECSサービスを停止するEventBridgeルール
resource "aws_cloudwatch_event_rule" "stop_ecs_rule" {
  name                = "stop-ecs-at-21h"
  schedule_expression = "cron(0 12 * * ? *)"
}

# EventBridgeルールとLambda関数を紐付けるターゲット
resource "aws_cloudwatch_event_target" "start_ecs_target" {
  rule      = aws_cloudwatch_event_rule.start_ecs_rule.name
  target_id = "start-ecs-target"
  arn       = aws_lambda_function.start_ecs_function.arn
}

resource "aws_cloudwatch_event_target" "stop_ecs_target" {
  rule      = aws_cloudwatch_event_rule.stop_ecs_rule.name
  target_id = "stop-ecs-target"
  arn       = aws_lambda_function.stop_ecs_function.arn
}

# EventBridgeがLambda関数を呼び出す権限
resource "aws_lambda_permission" "allow_cloudwatch_to_start_ecs" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_ecs_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_ecs_rule.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_stop_ecs" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_ecs_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_ecs_rule.arn
}

#shadowdata
# 毎日AM2時(JST)にEC2を起動するEventBridgeルール (UTC 17:00)
resource "aws_cloudwatch_event_rule" "start_ec2_rule" {
  name                = "start-ec2-at-2h-jst"
  schedule_expression = "cron(0 17 * * ? *)" 

}

# 毎日AM3時(JST)にEC2を停止するEventBridgeルール (UTC 18:00)
resource "aws_cloudwatch_event_rule" "stop_ec2_rule" {
  name                = "stop-ec2-at-3h-jst"
  schedule_expression = "cron(35 17 * * ? *)"
}

# EventBridgeルールとLambda関数を紐付けるターゲット (EC2起動)
resource "aws_cloudwatch_event_target" "start_ec2_target" {
  rule      = aws_cloudwatch_event_rule.start_ec2_rule.name
  target_id = "start-ec2-target"
  # EC2を起動するLambda関数を指定 (lambda.tfに追加する予定の関数)
  arn       = aws_lambda_function.start_ec2_function.arn 
}

# EventBridgeルールとLambda関数を紐付けるターゲット (EC2停止)
resource "aws_cloudwatch_event_target" "stop_ec2_target" {
  rule      = aws_cloudwatch_event_rule.stop_ec2_rule.name
  target_id = "stop-ec2-target"
  # EC2を停止するLambda関数を指定 (lambda.tfに追加する予定の関数)
  arn       = aws_lambda_function.stop_ec2_function.arn
}

# EventBridgeがLambda関数を呼び出す権限 (EC2起動)
resource "aws_lambda_permission" "allow_cloudwatch_to_start_ec2" {
  statement_id  = "AllowExecutionFromCloudWatchForEC2Start"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_ec2_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_ec2_rule.arn
}

# EventBridgeがLambda関数を呼び出す権限 (EC2停止)
resource "aws_lambda_permission" "allow_cloudwatch_to_stop_ec2" {
  statement_id  = "AllowExecutionFromCloudWatchForEC2Stop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_ec2_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_ec2_rule.arn
}
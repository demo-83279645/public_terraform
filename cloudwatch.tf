# CloudWatch Logs Group for ECS task
resource "aws_cloudwatch_log_group" "app_log_group" {
  name = "/ecs/${var.app_name}-app-task"
}

# 統合された単一のCloudWatchアラーム
resource "aws_cloudwatch_metric_alarm" "health_alarm" {
  alarm_name          = "${var.app_name}-health-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  dimensions = {
    LoadBalancer = aws_lb.app_lb.arn_suffix
    TargetGroup  = aws_lb_target_group.app_tg.arn_suffix
  }
  
  alarm_actions = [aws_sns_topic.maintenance_notification.arn]
  ok_actions    = [aws_sns_topic.maintenance_notification.arn]

  treat_missing_data = "breaching"
}

# SNS配信ログのためのCloudWatchロググループ
resource "aws_cloudwatch_log_group" "sns_delivery_log_group" {
  name = "${var.app_name}-sns-delivery-logs"
  retention_in_days = 7
}
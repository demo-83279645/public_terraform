resource "aws_sfn_state_machine" "shadow_data_pipeline" {
  
  name     = "${var.app_name}-ShadowDataPipeline"
  role_arn = aws_iam_role.sfn_exec_role.arn
  type     = "STANDARD" # 実行時間が長いためスタンダードタイプ推奨

  definition = jsonencode({
    Comment = "日影データ生成パイプライン"
    StartAt = "ShadowGeneratorFunction"
    States = {
      "ShadowGeneratorFunction" = {
        Type     = "Task"
        Resource = aws_lambda_function.shadow_generator.arn # 直接Lambda ARNを指定する
        Parameters = {
          # Step Functionsの実行入力をLambdaのイベントペイロードに渡す
          "date_to_process.$" = "$$.Execution.Input.date", # 例: {"date": "20250921"}
          "input_key.$"       = "$$.Execution.Input.input_key", 
          "output_bucket"     = aws_s3_bucket.output_bucket.bucket
        }
        End = true
      }
    }
  })
}
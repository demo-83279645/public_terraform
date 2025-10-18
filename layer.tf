resource "aws_lambda_layer_version" "custom_geopandas_layer" {
  layer_name      = "${var.app_name}-geopandas-lambda-deploy"
  # ステップ1で定義したS3バケットとオブジェクトを参照
  s3_bucket       = aws_s3_bucket.lambda_layer_bucket.id
  s3_key          = aws_s3_object.geopandas_layer_zip.key
  description     = "GeoPandas Layer built from GeoLambda template (Python 3.6/3.7 build for 3.12 runtime)"
  # Lambda関数 'shadow_generator'のランタイムに合わせて python3.12 を指定
  #compatible_runtimes = ["python3.12"] 
  compatible_runtimes = ["python3.9"]
  
}
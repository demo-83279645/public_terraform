# 2. EC2 API用 VPCインターフェイスエンドポイント (com.amazonaws.<region>.ec2)
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.main.id # 既存のVPCリソースIDに合わせる
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  
  # Lambdaを配置するプライベートサブネットを指定
  # 既存の private_subnet リソースIDのリストを仮定
  subnet_ids          = aws_subnet.private.*.id 
  
  # 作成したセキュリティグループを割り当て
  security_group_ids  = [aws_security_group.lambda_endpoint_sg.id] 
  
  private_dns_enabled = true

  tags = {
    Name = "${var.app_name}-ec2-endpoint"
  }
}
resource "aws_security_group" "private_ec2" {
  name        = "${var.app_name}-private-ec2-sg"
  description = "Allow internal traffic to private EC2"
  vpc_id      = aws_vpc.main.id

  # Inbound Rules:
  # 同じSG内のトラフィックを許可 (インスタンス間通信)
  ingress {
    description = "Allow all from self"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ## Public SubnetからのHTTP/Appトラフィックを許可
  #ingress {
  #  description = "Allow HTTP/App traffic from Public Subnets"
  #  from_port   = 22
  #  to_port     = 22
  #  protocol    = "tcp"
  #  cidr_blocks = var.my_ip_cidr
  #}

  # Outbound Rules:
  # プライベートサブネットなので、基本的にVPC内(ローカル)への通信のみ。
  # 0.0.0.0/0 の全許可も可能ですが、ここでは制限します。
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-private-ec2-sg"
  }
}

# ec2
resource "aws_instance" "app_server" {
  count         = length(var.private_subnet_cidrs)
  ami           = "ami-0296f4d1f79c0f298" # 指定されたAMI
  instance_type = "t3.medium"               # インスタンスタイプは適切なものを指定
  
subnet_id     = element(aws_subnet.private.*.id, count.index)
  
  # 【★重要：この行に変更します】
  vpc_security_group_ids = [
    aws_security_group.private_ec2.id,
  ]
  # プライベートインスタンスのため、パブリックIPは割り当てない (デフォルト)
  associate_public_ip_address = false 
  
  # key_name = "your-key-pair" # 必要に応じてSSHキーを指定
  key_name = "${var.key_pair_name}"

# MyS3RoleFullAccessという名前のIAMロールに対応するインスタンスプロファイルを指定
  iam_instance_profile = "MyS3RoleFullAccess"

  tags = {
    Name = "${var.app_name}-private-ec2-${count.index + 1}"
  }
}

# 1. LambdaおよびVPCエンドポイント用のセキュリティグループ
resource "aws_security_group" "lambda_endpoint_sg" {
  name        = "${var.app_name}-lambda-endpoint-sg"
  description = "Allows outbound HTTPS from Lambda to VPC Endpoints"
  vpc_id      = aws_vpc.main.id # 既存のVPCリソースIDに合わせる

  # インバウンドルール (VPCエンドポイント用)
  # LambdaがアタッチされているセキュリティグループからのHTTPS (443) を許可
  ingress {
    description = "Allow HTTPS from Lambda SG"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # Lambda関数に後ほど割り当てるセキュリティグループIDを指定
    self        = true
  }
  
  # アウトバウンドルール (Lambda用)
  # VPCエンドポイントへのアクセスとして、アウトバウンドHTTPSを許可
  egress {
    description = "Allow outbound to EC2 API via Endpoint"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # 宛先としてVPCエンドポイントのPrivate IPレンジ (VPC CIDR) を指定するか、ここでは簡潔に全許可
    cidr_blocks = ["0.0.0.0/0"] 
  }
  
  tags = {
    Name = "${var.app_name}-lambda-endpoint-sg"
  }
}
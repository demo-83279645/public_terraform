# vpc.tf
# データソースとして利用可能なAZのリストを取得
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.app_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.app_name}-igw"
  }
}

# Public Subnets (Fargate and ALB will reside here)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index] # ここでAZのリストを参照
  tags = {
    Name = "${var.app_name}-public-subnet-${count.index + 1}"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${var.app_name}-public-rt"
  }
}

# Associate Public Route Table with Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  # プライベートサブネットなので map_public_ip_on_launch はデフォルト(false)
  availability_zone = data.aws_availability_zones.available.names[count.index] # AZのリストを参照
  tags = {
    Name = "${var.app_name}-private-subnet-${count.index + 1}"
  }
}

# Private Route Table (単一)
# 全てのプライベートサブネットで使用するルートテーブルを1つだけ作成します。
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  # インターネットへのルート (0.0.0.0/0) は追加しません
  tags = {
    Name = "${var.app_name}-private-rt"
  }
}

# Associate Private Route Table with ALL Private Subnets
# 全てのプライベートサブネットに、単一のプライベートルートテーブルを関連付けます。
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id 
}
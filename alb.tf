# alb.tf
resource "aws_security_group" "lb_sg" {
  name   = "${var.app_name}-lb-sg"
  vpc_id = aws_vpc.main.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Add this block to allow HTTPS traffic on port 443
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # インターネット全体からのHTTPSアクセスを許可
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Security Group for the Fargate task
resource "aws_security_group" "app_sg" {
  name   = "${var.app_name}-app-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "${var.app_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = aws_subnet.public.*.id
}

# Target Group for the ALB
resource "aws_lb_target_group" "app_tg" {
  name     = "${var.app_name}-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/"
    interval = 30
    timeout  = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

# New HTTPS Listener on port 443
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# HTTP to HTTPS redirect listener
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

## LB Listener
#resource "aws_lb_listener" "http" {
#  load_balancer_arn = aws_lb.app_lb.arn
#  port              = 80
#  protocol          = "HTTP"
#
#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.app_tg.arn
#  }
#}
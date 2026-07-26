variable "name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "public_subnet_ids" {
  type = list(string)
}
variable "security_group_id" {
  type = string
}
variable "certificate_arn" {
  description = "ACM cert for HTTPS listener"
  type        = string
}
variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = true
  enable_http2                = true

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_lb_target_group" "grafana" {
  name        = "${var.name}-grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # EKS pods via AWS Load Balancer Controller

  health_check {
    path                = "/api/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.name}-frontend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port               = 443
  protocol           = "HTTPS"
  ssl_policy         = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn    = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "grafana" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  condition {
    host_header {
      values = ["grafana.*"]
    }
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port               = 80
  protocol           = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

output "alb_dns_name"        { value = aws_lb.this.dns_name }
output "grafana_tg_arn"      { value = aws_lb_target_group.grafana.arn }
output "frontend_tg_arn"     { value = aws_lb_target_group.frontend.arn }

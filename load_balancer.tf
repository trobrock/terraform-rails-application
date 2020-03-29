resource "aws_security_group" "lb" {
  name        = "${var.name}-lb"
  description = "controls access to the ALB for ${var.name}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.enable_ssl ? [1] : []
    content {
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "main" {
  name            = "${var.name}-ecs"
  subnets         = var.public_subnets
  security_groups = [aws_security_group.lb.id]
}

resource "aws_alb_target_group" "web" {
  name                 = "${var.name}-ecs"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = "60"

  health_check {
    path = "/ping"
  }
}

resource "aws_alb_listener" "ssl" {
  count = var.enable_ssl ? 1 : 0

  load_balancer_arn = aws_alb.main.id
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    target_group_arn = aws_alb_target_group.web.id
    type             = "forward"
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.main.id
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.enable_ssl ? [1] : []
    content {
      type = "redirect"

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.enable_ssl ? [] : [1]
    content {
      target_group_arn = aws_alb_target_group.web.id
      type             = "forward"
    }
  }
}

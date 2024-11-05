# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  name                = "csye6225-asg"
  default_cooldown    = 60
  desired_capacity    = 3
  max_size            = 5
  min_size            = 3
  vpc_zone_identifier = aws_subnet.public_subnets[*].id
  target_group_arns   = [aws_lb_target_group.app_target_group.arn]

  launch_template {
    id = aws_launch_template.app_launch_template.id
  }

  tag {
    key                 = "webapp"
    value               = "${var.vpc_name}-app-instance"
    propagate_at_launch = true
  }
}
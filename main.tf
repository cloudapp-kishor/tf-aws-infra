provider "aws" {
  region = var.region
}

# Fetch available Availability Zones dynamically
data "aws_availability_zones" "available" {
  state = "available"
}

# Create the VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# Create public subnets dynamically based on VPC CIDR and availability zones
resource "aws_subnet" "public_subnets" {
  count                   = var.subnet_count
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index) # Generating subnet CIDRs dynamically
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-subnet-${count.index + 1}"
  }
}

# Create private subnets dynamically based on VPC CIDR and availability zones
resource "aws_subnet" "private_subnets" {
  count             = var.subnet_count
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10) # Offset for private subnets
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "${var.vpc_name}-private-subnet-${count.index + 1}"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Create a public route table and associate public subnets with it
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_association" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Add a route to the Internet Gateway in the public route table
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Create a private route table and associate private subnets with it
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.vpc_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_association" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# Load Balancer Security Group
resource "aws_security_group" "load_balancer_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vpc_name}-lb-sg"
  }
}

# Create Security Group for Application
resource "aws_security_group" "application_security_group" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "Allow traffic from Load Balancer"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_sg.id]
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vpc_name}-application-sg"
  }
}


# Create Security Group for RDS instance MySQL
resource "aws_security_group" "db_security_group" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    description     = "Allow MySQL traffic from the application_security_group only"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.application_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vpc_name}-db-sg"
  }
}


# Create DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.vpc_name}-db-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id

  tags = {
    Name = "${var.vpc_name}-db-subnet-group"
  }
}


# Create an RDS Parameter Group
resource "aws_db_parameter_group" "rds_parameter_group" {
  name        = "${var.db_engine}-parameter-group"
  family      = var.db_group_family
  description = "RDS parameter group for ${var.db_engine}"
  tags = {
    Name = "${var.vpc_name}-rds-pg"
  }
}


# Create RDS instance
resource "aws_db_instance" "rds_instance" {
  identifier             = "csye6225"
  engine                 = var.db_engine
  instance_class         = "db.t3.micro"
  allocated_storage      = 15
  username               = var.db_username
  password               = var.db_password
  db_name                = var.db_name
  parameter_group_name   = aws_db_parameter_group.rds_parameter_group.name
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  skip_final_snapshot    = true

  tags = {
    Name = "${var.vpc_name}-rds-instance"
  }
}



# Create EC2 Instance
# resource "aws_instance" "webapp_instance" {

#   depends_on = [
#     aws_security_group.application_security_group
#   ]
#   ami                         = var.ami_id
#   instance_type               = "t2.micro"
#   subnet_id                   = aws_subnet.public_subnets[0].id
#   security_groups             = [aws_security_group.application_security_group.id]
#   associate_public_ip_address = true
#   iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name

#   root_block_device {
#     volume_size           = 25
#     volume_type           = "gp2"
#     delete_on_termination = true
#   }

#   user_data = <<-EOF
#               #!/bin/bash
#               rm -f /opt/webapp/.env
#               touch /opt/webapp/.env
#               echo "DB_USER='${var.db_username}'" >> /opt/webapp/.env
#               echo "DB_PASSWORD='${var.db_password}'" >> /opt/webapp/.env
#               echo "DB_NAME='${var.db_name}'" >> /opt/webapp/.env
#               echo "PORT=${var.app_port}" >> /opt/webapp/.env
#               echo "DB_HOST='${aws_db_instance.rds_instance.address}'" >> /opt/webapp/.env
#               echo "S3_BUCKET_NAME='${aws_s3_bucket.csye6225_s3_bucket.bucket}'" >> /opt/webapp/.env
#               sudo systemctl restart webapp.service
#               /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start
#               sudo npm install -g statsd-cloudwatch-backend
#               statsd /opt/webapp/app/packer/statsd_config.js
#               EOF

#   tags = {
#     Name = "${var.vpc_name}-webapp-instance"
#   }

#   # Disable accidental termination protection
#   lifecycle {
#     prevent_destroy = false
#   }
# }


# Generate a unique UUID for the bucket name
resource "random_uuid" "bucket_uuid" {}

# Create a private S3 bucket with default encryption and lifecycle policy
resource "aws_s3_bucket" "csye6225_s3_bucket" {
  bucket        = random_uuid.bucket_uuid.result
  acl           = "private"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle" {
  bucket = aws_s3_bucket.csye6225_s3_bucket.id

  rule {
    id = "Transition to STANDARD_IA"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    status = "Enabled"
  }
}

# IAM Role for EC2 instance
resource "aws_iam_role" "ec2_role" {
  name = "${var.vpc_name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Effect = "Allow"
    }]
  })
}

# Create an IAM Instance Profile and associate it with the IAM role
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.vpc_name}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Update Route 53 DNS settings
resource "aws_route53_record" "app_record" {
  zone_id = var.route53_zone_id
  name    = "${var.env}.${var.domain_name}"
  type    = "A"
  alias {
    evaluate_target_health = true
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
  }
}

# IAM Policy for S3 and RDS access
resource "aws_iam_policy" "S3_access_policy" {
  name        = "${var.vpc_name}-access-policy"
  description = "IAM policy for S3 and RDS access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:PutLifecycleConfiguration",
          "s3:PutObjectAcl",
          "s3:GetObjectAcl",
          "s3:PutBucketAcl"
        ]
        Resource = [
          "${aws_s3_bucket.csye6225_s3_bucket.arn}/*",
          "${aws_s3_bucket.csye6225_s3_bucket.arn}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:Connect"
        ]
        Resource = aws_db_instance.rds_instance.arn
      }
    ]
  })
}

# Attach policy to EC2 role
resource "aws_iam_role_policy_attachment" "ec2_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.S3_access_policy.arn
}

# IAM Policy to allow CloudWatch actions
resource "aws_iam_policy" "cloudwatch_agent_policy" {
  name        = "CloudWatchAgentPolicy"
  description = "Allows CloudWatch agent to publish metrics and logs and describe EC2 tags"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "cloudwatch:PutMetricData",
          "ec2:DescribeTags",
          "cloudwatch:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# Attach policy to IAM Role
resource "aws_iam_role_policy_attachment" "attach_cloudwatch_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cloudwatch_agent_policy.arn
}

# Create Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "${var.vpc_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer_sg.id]
  subnets            = aws_subnet.public_subnets[*].id

  tags = {
    Name = "${var.vpc_name}-alb"
  }
}

# Target Group for Auto Scaling Group
resource "aws_lb_target_group" "app_target_group" {
  name     = "${var.vpc_name}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    path                = "/healthz"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# Listener for Load Balancer
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}

# Launch Template for Auto Scaling Group
resource "aws_launch_template" "app_launch_template" {
  depends_on = [
    aws_security_group.application_security_group
  ]
  name          = "${var.vpc_name}-lt"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }
  user_data = base64encode(<<-EOF
              #!/bin/bash
              rm -f /opt/webapp/.env
              touch /opt/webapp/.env
              echo "DB_USER='${var.db_username}'" >> /opt/webapp/.env
              echo "DB_PASSWORD='${var.db_password}'" >> /opt/webapp/.env
              echo "DB_NAME='${var.db_name}'" >> /opt/webapp/.env
              echo "PORT=${var.app_port}" >> /opt/webapp/.env
              echo "DB_HOST='${aws_db_instance.rds_instance.address}'" >> /opt/webapp/.env
              echo "S3_BUCKET_NAME='${aws_s3_bucket.csye6225_s3_bucket.bucket}'" >> /opt/webapp/.env
              sudo systemctl restart webapp.service
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start
              sudo npm install -g statsd-cloudwatch-backend
              statsd /opt/webapp/app/packer/statsd_config.js
              EOF
  )

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.application_security_group.id]
  }
}

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
    id      = aws_launch_template.app_launch_template.id
  }

  tag {
    key                 = "webapp"
    value               = "${var.vpc_name}-app-instance"
    propagate_at_launch = true
  }
}

# CloudWatch Alarm for Scaling Up (CPU > 5%)
resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "${var.vpc_name}-scale-up-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "Alarm for scaling up when CPU usage is above 5%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_up_policy.arn]
}

# CloudWatch Alarm for Scaling Down (CPU < 3%)
resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "${var.vpc_name}-scale-down-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 3
  alarm_description   = "Alarm for scaling down when CPU usage is below 3%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_down_policy.arn]
}

# Auto Scaling Policy for Scaling Up
resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "${var.vpc_name}-scale-up-policy"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

# Auto Scaling Policy for Scaling Down
resource "aws_autoscaling_policy" "scale_down_policy" {
  name                   = "${var.vpc_name}-scale-down-policy"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}
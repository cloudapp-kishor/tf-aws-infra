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
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Application traffic"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
resource "aws_instance" "webapp_instance" {

  depends_on = [
    aws_security_group.application_security_group
  ]
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnets[0].id
  security_groups             = [aws_security_group.application_security_group.id]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  root_block_device {
    volume_size           = 25
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = <<-EOF
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
              EOF

  tags = {
    Name = "${var.vpc_name}-webapp-instance"
  }

  # Disable accidental termination protection
  lifecycle {
    prevent_destroy = false
  }
}

# Generate a unique UUID for the bucket name
resource "random_uuid" "bucket_uuid" {}

# Create a private S3 bucket with default encryption and lifecycle policy
resource "aws_s3_bucket" "csye6225_s3_bucket" {
  bucket = "${random_uuid.bucket_uuid.result}"
  acl    = "private"
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
    id     = "Transition to STANDARD_IA"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    status = "Enabled"
  }
}

# IAM Role for EC2 instance
resource "aws_iam_role" "ec2_role" {
  name               = "${var.vpc_name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Effect    = "Allow"
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
  records = [aws_instance.webapp_instance.public_ip]
  ttl     = 60
}

# IAM Policy for S3 and RDS access
resource "aws_iam_policy" "access_policy" {
  name        = "${var.vpc_name}-access-policy"
  description = "IAM policy for S3 and RDS access"
  policy      = jsonencode({
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
  policy_arn = aws_iam_policy.access_policy.arn
}
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
              echo "SNS_TOPIC_ARN='${aws_sns_topic.user_registration_topic.arn}'" >> /opt/webapp/.env
              echo "URL='${var.env}.${var.domain_name}'" >> /opt/webapp/.env
              sudo systemctl restart webapp.service
              EOF
  )

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.application_security_group.id]
  }
}
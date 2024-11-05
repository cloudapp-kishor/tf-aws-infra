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
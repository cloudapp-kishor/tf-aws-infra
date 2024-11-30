data "aws_caller_identity" "current" {}

# KMS Key for EC2 EBS Encryption
resource "aws_kms_key" "ec2_ebs_kms" {
  description             = "KMS key for EC2 EBS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

# KMS key for RDS
resource "aws_kms_key" "rds_kms" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

# KMS key for S3
resource "aws_kms_key" "s3_kms" {
  description             = "KMS key for S3 encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

# KMS key for Secrets Manager
resource "aws_kms_key" "secrets_kms" {
  description             = "KMS key for Secrets Manager encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

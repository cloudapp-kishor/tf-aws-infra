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
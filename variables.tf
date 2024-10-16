variable "region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "vpc_name" {
  description = "Name for the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "subnet_count" {
  description = "The number of subnets to create"
  type        = number
  default     = 3
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
}

variable "app_port" {
  description = "Port on which the application runs"
}

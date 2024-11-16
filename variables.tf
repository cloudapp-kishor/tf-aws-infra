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

variable "db_port" {
  description = "Port on which the database runs"
}

variable "db_engine" {
  description = "MySQL database engine"
}

variable "db_group_family" {
  description = "RDS Parameter group family"
}

variable "db_username" {
  description = "Database userame for RDS instance"
}

variable "db_password" {
  description = "Database password for RDS instance"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
}

variable "route53_zone_id" {
  description = "Zone ID for route 53"
}

variable "domain_name" {
  description = "Domain name"
}

variable "env" {
  description = "dev or demo"
}

variable "sendgrid_api_key" {
  description = "sendgrid api key"
}
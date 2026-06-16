variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state storage"
  type        = string
}

variable "table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform-locks"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "azs" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI for us-east-1 (update per region/patch cycle)"
  type        = string
  default     = "ami-0e001c9271cf7f3b9"
}

variable "key_name" {
  type    = string
  default = "observability-prod-key"
}

variable "certificate_arn" {
  type = string
}

variable "internal_zone_id" {
  description = "Route53 private zone ID for *.observability-prod.internal"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile granting SSM (for Ansible connectivity), CloudWatch, S3 backup access"
  type        = string
  default     = "observability-ec2-profile"
}

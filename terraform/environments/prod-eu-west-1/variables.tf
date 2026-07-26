variable "azs" {
  default = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}
variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI for eu-west-1"
  type        = string
  default     = "ami-0694d931cee176e7d"
}
variable "key_name" {
  type    = string
  default = "observability-prod-key-euw1"
}
variable "certificate_arn" {
  type = string
}
variable "internal_zone_id" {
  type = string
}
variable "instance_profile_name" {
  type    = string
  default = "observability-ec2-profile"
}

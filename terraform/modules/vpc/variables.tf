variable "name" {
  description = "Name prefix for all VPC resources"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across (min 3 for prod)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ (EKS nodes, ClickHouse, backend)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ (ALB, NAT gateways)"
  type        = list(string)
}

variable "database_subnet_cidrs" {
  description = "Isolated subnet CIDRs for ClickHouse/Keeper data plane"
  type        = list(string)
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

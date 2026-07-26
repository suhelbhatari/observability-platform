variable "name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "database_subnet_ids" {
  description = "One subnet per AZ; shards are distributed round-robin across these"
  type        = list(string)
}
variable "security_group_id" {
  type = string
}
variable "instance_type" {
  type    = string
  default = "r6g.2xlarge" # memory-optimized, Graviton - good ClickHouse price/perf
}
variable "ami_id" {
  description = "Base AMI (Ubuntu 22.04 LTS or Amazon Linux 2023). Ansible configures ClickHouse on top."
  type        = string
}
variable "key_name" {
  type = string
}
variable "shard_count" {
  description = "Number of shards (horizontal data split)"
  type        = number
  default     = 3
}
variable "replica_count" {
  description = "Replicas per shard (HA within a shard)"
  type        = number
  default     = 2
}
variable "data_volume_size_gb" {
  type    = number
  default = 2000
}
variable "data_volume_iops" {
  type    = number
  default = 10000
}
variable "instance_profile_name" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}

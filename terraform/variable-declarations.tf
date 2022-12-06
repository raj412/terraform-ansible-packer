variable "lf_vpc_cidr" {}
variable "lf_vpc_reverse_cidr" {}
variable "lf_vpc_cidr_range" {}
variable "lf_vpc_subnet_start" {}
# Instance counts
variable "lf_linux_count" {}

variable "lf-subnets" {
  type    = list(string)
  default = ["a", "b", "c"]
}
variable "lf_region" {}
variable "lf_pub_key" {}

variable "lf_env" {
  type    = string
  default = "DEV"
}

variable "infra_net_tgw_AWS_ACCESS_KEY_ID" {}
variable "infra_net_tgw_AWS_SECRET_ACCESS_KEY" {}
variable "infra_net_tgw_AWS_DEFAULT_REGION" {}
variable "create_vpc" {
  type = bool
  description = "create a vpc or not"
}

variable tag_name {
  type = object(
    {
      tf-tag-name = string
    }
    )
  description = "add this tag to all resources created by this script"
  default = { tf-tag-name = "CustomedVPC" }
}

variable "vpc_parameters" {
  type = any
}

variable "dhcp_options" {
  type = any
}

variable "igw" {
  type = any
}

variable "subnets_para" {
  type = list(any)
  description = "define subnets"
}

variable "sub_rt" {
  type = list(any)
  description = "route tables"
}

variable "ngw" {
  type = list(any)
  description = "nat gateway"
}

variable "nacl" {
  type = list(any)
  description = "network acl"
}
provider "aws" {
  region = "ca-central-1"
}

####################################################################################
#
# create a vpc
#
####################################################################################

resource "aws_vpc" "this" {
  count = var.create_vpc ? 1 : 0
  cidr_block = var.vpc_parameters.cidr_block
  instance_tenancy = lookup(var.vpc_parameters, "instance_tenancy", "default")
  enable_dns_support = lookup(var.vpc_parameters, "enable_dns_support", true)
  enable_dns_hostnames = lookup(var.vpc_parameters, "enable_dns_hostnames", true)
  assign_generated_ipv6_cidr_block = lookup(var.vpc_parameters, "assign_generated_ipv6_cidr_block", false)
  tags = merge(var.tag_name, lookup(var.vpc_parameters, "tags", {}))
}

####################################################################################
#
# create dhcp options
#
####################################################################################

resource "aws_vpc_dhcp_options" "this" {
  count = var.create_vpc && var.dhcp_options.create ? 1 : 0

  domain_name          = lookup(var.dhcp_options, "service.consul", "")
  domain_name_servers  = lookup(var.dhcp_options, "domain_name_servers", [])
  ntp_servers          = lookup(var.dhcp_options, "ntp_servers", [])
  netbios_name_servers = lookup(var.dhcp_options, "netbios_name_servers", [])
  netbios_node_type    = lookup(var.dhcp_options, "netbios_node_type", 2)

  tags = merge(var.tag_name, lookup(var.dhcp_options, "tags", {}))
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  count = var.create_vpc && var.dhcp_options.create ? 1 : 0

  vpc_id          = aws_vpc.this[0].id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}

####################################################################################
#
# create internet gateway
#
####################################################################################

resource "aws_internet_gateway" "this" {
  count = var.create_vpc && var.igw.create ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  tags = merge(
    var.tag_name, lookup(var.igw, "tags", {})
  )
}

####################################################################################
#
# fetch azs' info and create subnets
#
####################################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "this" {
  count = var.create_vpc && length(var.subnets_para) > 0 ? length(var.subnets_para) : 0

  vpc_id     = aws_vpc.this[0].id
  cidr_block = cidrsubnet(var.vpc_parameters.cidr_block, var.subnets_para[count.index].cidr_bit, var.subnets_para[count.index].cidr_num)

  tags = merge(
    var.tag_name, 
    { Name = var.subnets_para[count.index].name }
  )
}

####################################################################################
#
# create customized route tables and associate them to subnets
#
####################################################################################

resource "aws_route_table" "this" {
  count = var.create_vpc && length(var.sub_rt) > 0 ? length(var.sub_rt) : 0

  vpc_id = aws_vpc.this[0].id

  dynamic "route" {
    for_each = contains(keys(var.sub_rt[count.index]), "ipv4_route") ? var.sub_rt[count.index].ipv4_route : []

    content {
      cidr_block = route.value.destination

      gateway_id = contains(keys(route.value), "gateway_id_index") ? aws_internet_gateway.this[route.value.gateway_id_index].id : null

      nat_gateway_id = contains(keys(route.value), "nat_gateway_id_index") ? aws_nat_gateway.this[route.value.nat_gateway_id_index].id : null

    }
  }

  dynamic "route" {
    for_each = contains(keys(var.sub_rt[count.index]), "ipv6_route") ? var.sub_rt[count.index].ipv6_route : []

    content {
      ipv6_cidr_block = route.value.destination

      egress_only_gateway_id = contains(keys(route.value), "egress_only_gateway_id_index") ? aws_egress_only_gateway.this[route.value.egress_only_gateway_id_index].id : null
    }
  }

  tags = merge(var.tag_name,
    var.sub_rt[count.index].tags
    )
}




resource "aws_route_table_association" "this" {
  count = var.create_vpc && length(var.subnets_para) > 0 ? length(var.subnets_para) : 0

  subnet_id      = aws_subnet.this[count.index].id

  # set default route table for subnets without rt_index paramter.
  route_table_id = contains(keys(var.subnets_para[count.index]), "rt_index") ? aws_route_table.this[var.subnets_para[count.index].rt_index].id : aws_vpc.this[0].default_route_table_id

}

####################################################################################
#
# create nat gateway and associated to route table
#
####################################################################################

resource "aws_nat_gateway" "this" {
  count = var.create_vpc && length(var.ngw) > 0 ? length(var.ngw) : 0

  allocation_id = aws_eip.this[count.index].id
  subnet_id     = aws_subnet.this[var.ngw[count.index].subnet_id_index].id

  tags = merge(var.tag_name, var.ngw[count.index].tags)
}

resource "aws_eip" "this" {
  count = var.create_vpc && length(var.ngw) > 0 ? length(var.ngw) : 0

  vpc = true
}


####################################################################################
#
# create network acl and associated to subnets
#
####################################################################################

resource "aws_network_acl" "this" {
  vpc_id = aws_vpc.this[0].id

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "10.3.0.0/18"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.3.0.0/18"
    from_port  = 80
    to_port    = 80
  }

  tags = {
    Name = "main"
  }
}
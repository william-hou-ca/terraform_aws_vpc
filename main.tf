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
# create subnets
#
####################################################################################

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
  count = var.create_vpc && length(var.nacl) > 0 ? length(var.nacl) : 0

  vpc_id = aws_vpc.this[0].id

  # associate network acl to subnets via the index number of resource aws_subnet.this
  subnet_ids = [ for s in var.nacl[count.index].subnet_ids_index : aws_subnet.this[s].id ]

  dynamic "egress" {
    for_each = contains(keys(var.nacl[count.index]), "egress") ? var.nacl[count.index].egress : []

    content {
      protocol   = egress.value.protocol
      rule_no    = egress.value.rule_num
      action     = egress.value.action
      cidr_block = egress.value.cidr_block
      from_port  = egress.value.protocol == "-1" ? 0 : egress.value.from_port
      to_port    = egress.value.protocol == "-1" ? 0 : egress.value.to_port
    }
  }

  dynamic "ingress" {
    for_each = contains(keys(var.nacl[count.index]), "ingress") ? var.nacl[count.index].ingress : []

    content {
      protocol   = ingress.value.protocol
      rule_no    = ingress.value.rule_num
      action     = ingress.value.action
      cidr_block = ingress.value.cidr_block
      from_port  = ingress.value.protocol == "-1" ? 0 : ingress.value.from_port
      to_port    = ingress.value.protocol == "-1" ? 0 : ingress.value.to_port
    }
  }

  tags = merge(var.tag_name, lookup(var.nacl[count.index], "tags", {}))
}

####################################################################################
#
# create security groups
#
####################################################################################

resource "aws_security_group" "this" {
  count = var.create_vpc && length(var.sg) > 0 ? length(var.sg) : 0

  name        = var.sg[count.index].name
  description = var.sg[count.index].description
  vpc_id      = aws_vpc.this[0].id

  dynamic "egress" {
    for_each = contains(keys(var.sg[count.index]), "egress") ? var.sg[count.index].egress : []

    content {
      protocol   = egress.value.protocol
      cidr_blocks  = egress.value.cidr_blocks 
      from_port  = egress.value.protocol == "-1" ? 0 : egress.value.from_port
      to_port    = egress.value.protocol == "-1" ? 0 : egress.value.to_port
      self = lookup(egress.value, "self", false)
      security_groups = contains(keys(egress.value), "security_groups") ? egress.value.security_groups : []
      prefix_list_ids = contains(keys(egress.value), "prefix_list_ids_index") ? [ for s in egress.value.prefix_list_ids_index : aws_ec2_managed_prefix_list.this[s].id] : []
    }
  }

  dynamic "ingress" {
    for_each = contains(keys(var.sg[count.index]), "ingress") ? var.sg[count.index].ingress : []

    content {
      protocol   = ingress.value.protocol
      cidr_blocks  = ingress.value.cidr_blocks 
      from_port  = ingress.value.protocol == "-1" ? 0 : ingress.value.from_port
      to_port    = ingress.value.protocol == "-1" ? 0 : ingress.value.to_port
      self = lookup(ingress.value, "self", false)
      security_groups = contains(keys(ingress.value), "security_groups") ? ingress.value.security_groups : []
      prefix_list_ids = contains(keys(ingress.value), "prefix_list_ids_index") ? [ for s in ingress.value.prefix_list_ids_index : aws_ec2_managed_prefix_list.this[s].id] : []
    }
  }

  tags = merge(var.tag_name, lookup(var.sg[count.index], "tags", {}))
}

####################################################################################
#
# create prefix lists and use them in security groups
#
####################################################################################

resource "aws_ec2_managed_prefix_list" "this" {
  count = var.create_vpc && length(var.prefix_list) > 0 ? length(var.prefix_list) : 0

  name           = var.prefix_list[count.index].name
  address_family = var.prefix_list[count.index].address_family
  max_entries    = var.prefix_list[count.index].max_entries

  dynamic "entry" {
    for_each = contains(keys(var.prefix_list[count.index]), "entry") ? var.prefix_list[count.index].entry : []

    content {
      cidr        = contains(keys(entry.value), "subnet_id_index") ? aws_subnet.this[entry.value.subnet_id_index].cidr_block : entry.value.cidr
      description = lookup(entry.value, "description", null)
    }
  }

  tags = merge(var.tag_name, lookup(var.prefix_list[count.index], "tags", {}))
}
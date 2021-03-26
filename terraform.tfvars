create_vpc = true

vpc_parameters = {
  cidr_block = "10.10.0.0/16"
  instance_tenancy = "default"
  tags = { Name = "tf-vpc"}
}

dhcp_options = {
  create = false
  domain_name          = "service.test"
  domain_name_servers  = ["127.0.0.1", "10.0.0.2"]
  ntp_servers          = ["127.0.0.1"]
  netbios_name_servers = ["127.0.0.1"]
  netbios_node_type    = 2
  tags = { env = "test-dhcp-options" }
}

igw = {
  create = true
  tags = { env = "test-igw"}
}

subnets_para = [
  {
    name = "tf-private-1"
    cidr_bit = 8
    cidr_num = 0
    rt_index = 1
  },
  {
    name = "tf-private-2"
    cidr_bit = 8
    cidr_num = 1
    rt_index = 2
  },
  {
    name = "tf-public-1"
    cidr_bit = 8
    cidr_num = 2
    rt_index = 0 # index number of sub_rt variable
  },
  {
    name = "tf-public-2"
    cidr_bit = 8
    cidr_num = 3
    rt_index = 0 # index number of sub_rt variable
  },
  {
    name = "tf-db-1"
    cidr_bit = 8
    cidr_num = 4
  },
  {
    name = "tf-db-2"
    cidr_bit = 8
    cidr_num = 5
  },  
]

sub_rt = [
  {
     tags = { Name = "rt-public"}
     ipv4_route = [
       {
         destination = "0.0.0.0/0"
         gateway_id_index = 0 # index number of gateway variable
       },
     ]
     ipv6_route = []
  },
  {
     tags = { Name = "rt-private-gw1"}
     ipv4_route = [
       {
         destination = "0.0.0.0/0"
         nat_gateway_id_index = 0 # index number of gateway variable
       },
     ]
     ipv6_route = []
  },
  {
     tags = { Name = "rt-private-gw2"}
     ipv4_route = [
       {
         destination = "0.0.0.0/0"
         nat_gateway_id_index = 1 # index number of gateway variable
       },       
     ]
     ipv6_route = []
  },  
]

ngw = [
  {
    tags = { Name = "ngw-1"}
    subnet_id_index = 2 # index number of public subnet in the variable subnets_para
  },
  {
    tags = { Name = "ngw-2"}
    subnet_id_index = 3 # index number of public subnet in the variable subnets_para
  },  
]

nacl = [
  {
    tags = { Name = "nacl-private"}
  }
]
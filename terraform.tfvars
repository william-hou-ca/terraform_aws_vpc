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
    subnet_ids_index = [0,1] # index id of variable subnets_para
    egress = [
      {
        protocol = "-1"
        rule_num = 100
        action = "allow"
        cidr_block = "0.0.0.0/0"
      },
    ]
    ingress = [
      {
        protocol = "tcp"
        rule_num = 100
        action = "allow"
        cidr_block = "10.10.0.0/23"
        from_port = 80
        to_port = 80
      },
      {
        protocol = "tcp"
        rule_num = 200
        action = "allow"
        cidr_block = "10.10.0.0/23"
        from_port = 22
        to_port = 22
      },
    ]
  },
  {
    tags = { Name = "nacl-db"}
    subnet_ids_index = [4,5] # index id of variable subnets_para
    egress = [
      {
        protocol = "-1"
        rule_num = 100
        action = "allow"
        cidr_block = "0.0.0.0/0"
      },
    ]
    ingress = [
      {
        protocol = "tcp"
        rule_num = 100
        action = "allow"
        cidr_block = "10.10.2.0/23"
        from_port = 3306
        to_port = 3306
      },
      {
        protocol = "tcp"
        rule_num = 200
        action = "allow"
        cidr_block = "10.10.2.0/23"
        from_port = 22
        to_port = 22
      },
    ]
  },
]

sg = [
  {
    name = "tf-sg-public"
    description = "Allow public inbound traffic"
    tags = { Name = "sg-public"}
    egress = [
      {
        protocol = "-1"
        cidr_blocks  = ["0.0.0.0/0"]
      },
    ]
    ingress = [
      {
        protocol = "tcp"
        cidr_blocks  = ["38.129.48.138/32", "24.37.254.72/29"]
        from_port = 80
        to_port = 80
        self = true
        security_groups = []
        prefix_list_ids_index = []
      },
      {
        protocol = "tcp"
        cidr_blocks  = ["38.129.48.138/32", "24.37.254.72/29"]
        from_port = 22
        to_port = 22
        self = false
        security_groups = []
        prefix_list_ids_index = []
      },
    ]
  },
  {
    name = "tf-sg-private"
    description = "Allow private inbound traffic"
    tags = { Name = "sg-private"}
    egress = [
      {
        protocol = "-1"
        cidr_blocks  = ["0.0.0.0/0"]
      },
    ]
    ingress = [
      {
        protocol = "tcp"
        cidr_blocks  = []
        from_port = 80
        to_port = 80
        self = true
        security_groups = []
        prefix_list_ids_index = [0]
      },
      {
        protocol = "tcp"
        cidr_blocks  = []
        from_port = 22
        to_port = 22
        self = true
        security_groups = []
        prefix_list_ids_index = [0]
      },
    ]
  },
]


prefix_list = [
  {
    name = "tf-prefixlist-public"
    address_family = "IPv4"
    max_entries    = 10
    entry = [
      {
        subnet_id_index = 2
        description = "cidr of subnet public 1"
      },
      {
        cidr = "10.10.3.0/24"
        description = "cidr of subnet public 2"
      },
    ]
  }
]
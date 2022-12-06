#########################################
# Define locals for building with vars  #
#########################################
locals {
  #####################
  # Networking Locals #
  #####################

  cidr           = "${var.vpc_cidr}.${var.vpc_subnet_start}.0/${var.vpc_cidr_range}"
  subnets        = [aws_subnet.subnet-1a.id, aws_subnet.subnet-1b.id, aws_subnet.subnet-1c.id]
  subnets_public = [aws_subnet.subnet-1a-public.id, aws_subnet.subnet-1b-public.id, aws_subnet.subnet-1c-public.id]
  subnets_fixed  = [aws_subnet.subnet-1a-fixed.id, aws_subnet.subnet-1b-fixed.id, aws_subnet.subnet-1c-fixed.id]
  fixed_subnets     = "${var.vpc_cidr}.${var.vpc_subnet_start + 7}"

  #########################
  # Linux Instance locals #
  #########################
  linux_fixed_ip = ["${local.fixed_subnets}.10",
    "${local.fixed_subnets}.43",
    "${local.fixed_subnets}.75",
    "${local.fixed_subnets}.11",
    "${local.fixed_subnets}.44",
  "None"]


  linux_hostname = ["dev-calix",
  "dev-netbox"]
  linux_apps = ["calix",
  "ntpd netbox", ]
  linux_image_private = [data.aws_ami.image-linux-centos.id,
    data.aws_ami.image-linux-ubuntu-dev.id]
  linux_instance_type           = ["m5.xlarge", "t3.medium", "t3.large", "t3.medium", "t3.medium", "t3.large", "t3.large"]
  linux_data_volume_size        = [200, 50, 100, 5, 5, 5]
  linux_data_volume_size_public = [5, 5, 5, 5, 5, 5, 5]
  linux_os_type                 = ["Centos", "Ubuntu", "Ubuntu", "Ubuntu", "Ubuntu", "Ubuntu", "Ubuntu", ]
  linux_os_ver                  = ["7.9", "20.04", "20.04", "20.04", "20.04", "20.04", "20.04", "20.04", ]
  linux_monitor                 = ["yes", "yes", "yes", "yes", "yes", "no"]
  linux_patch                   = ["yes", "yes", "yes", "yes", "yes", "yes", "yes", "yes"]

  # Configure instance policy
  linux_instance_profile = [aws_iam_instance_profile.instance-profile.name,
    aws_iam_instance_profile.instance-profile.name,
    aws_iam_instance_profile.instance-profile.name,
    aws_iam_instance_profile.certificate-profile.name,
  aws_iam_instance_profile.instance-profile.name]

  linux_security_groups = tolist([[local.sg-private, local.sg-calix],
  [local.sg-private, local.sg-netbox]])


  

  #############################
  # Configure Security groups #
  #############################

  # - moved to config - sg-private    = aws_security_group.private-sg.id
  sg-calix      = aws_security_group.calix-sg.id
  sg-netbox     = aws_security_group.netbox-sg.id
  sg-private    = aws_security_group.private-sg.id

}

###################################
# Assign Packer created images    #
###################################


data "aws_ami" "image-linux-ubuntu-dev" {
  most_recent = true
  filter {
    name   = "tag:Name"
    values = ["LitFibre-Ubuntu-20-Generic-*"]
  }
  owners = ["self"]
}


#######################################
# Host key - Must have for the build  #
#######################################

resource "aws_key_pair" "key" {
  key_name   = "build_key_dev"
  public_key = var.pub_key
}


##################
# Define the VPC #
##################

resource "aws_vpc" "vpc" {
  cidr_block           = local.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name    = "net-mgm-vpc"
  }
}


###################
# Public subnets  #
###################

resource "aws_subnet" "subnet-1a-public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${var.vpc_cidr}.${var.vpc_subnet_start + 3}.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = {
    Name    = "subnet-1a-public"
  }
  depends_on = [
    aws_internet_gateway.internet-gw
  ]
}

resource "aws_subnet" "subnet-1b-public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${var.vpc_cidr}.${var.vpc_subnet_start + 4}.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
  tags = {
    Name    = "subnet-1b-public"
  }
  depends_on = [
    aws_internet_gateway.internet-gw
  ]
}

resource "aws_subnet" "subnet-1c-public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${var.vpc_cidr}.${var.vpc_subnet_start + 5}.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = true
  tags = {
    Name    = "subnet-1c-public"
  }
  depends_on = [
    aws_internet_gateway.internet-gw
  ]
}

######################
# Public route table #
######################

resource "aws_route_table" "route-table-public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gw.id
  }

  tags = {
    Name    = "route-table-public"
  }
}

##########################################
# Public subnet route table associations #
##########################################

resource "aws_route_table_association" "subnet-1a-public" {
  subnet_id      = aws_subnet.subnet-1a-public.id
  route_table_id = aws_route_table.route-table-public.id
}

resource "aws_route_table_association" "subnet-1b-public" {
  subnet_id      = aws_subnet.subnet-1b-public.id
  route_table_id = aws_route_table.route-table-public.id
}

resource "aws_route_table_association" "subnet-1c-public" {
  subnet_id      = aws_subnet.subnet-1c-public.id
  route_table_id = aws_route_table.route-table-public.id
}


###################
# Private subnets #
###################

resource "aws_subnet" "subnet-1a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.vpc_cidr}.${var.vpc_subnet_start + 0}.0/24"
  availability_zone = "${var.region}a"
  tags = {
    Name    = "subnet-1a"
  }
}

resource "aws_subnet" "subnet-1b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.vpc_cidr}.${var.vpc_subnet_start + 1}.0/24"
  availability_zone = "${var.region}b"
  tags = {
    Name    = "subnet-1b"
  }
}

resource "aws_subnet" "subnet-1c" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.vpc_cidr}.${var.vpc_subnet_start + 2}.0/24"
  availability_zone = "${var.region}c"
  tags = {
    Name    = "subnet-1c"
  }
}

########################################
# Private subnets for fixed addressing #
########################################

resource "aws_subnet" "subnet-1a-fixed" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.vpc_cidr}.${var.vpc_subnet_start + 7}.0/27"
  availability_zone = "${var.region}a"
  tags = {
    Name        = "subnet-1a-fixed"
    description = "For fixed addresses"
  }
}

resource "aws_subnet" "subnet-1b-fixed" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.vpc_cidr}.${var.vpc_subnet_start + 7}.32/27"
  availability_zone = "${var.region}b"
  tags = {
    Name        = "subnet-1b-fixed"
    description = "For fixed addresses"
  }
}

resource "aws_subnet" "subnet-1c-fixed" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.vpc_cidr}.${var.vpc_subnet_start + 7}.64/27"
  availability_zone = "${var.region}c"
  tags = {
    Name        = "subnet-1c-fixed"
    description = "For fixed addresses"
  }
}

#########################################
# Private Route Tables for NAT gateways #
#########################################

data "aws_ec2_transit_gateway" "tgw" {
}


resource "aws_route_table" "route-table" {
  count  = 3
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.nat-gateway.*.id, count.index)
  }
  tags = {
    Name    = "route-table-${count.index}"

  }
}



# ########################################################
# # Private NAT Route Tables Private subnet associations #
# ########################################################

resource "aws_route_table_association" "subnet-1a" {
  subnet_id      = aws_subnet.subnet-1a.id
  route_table_id = aws_route_table.route-table.0.id
}

resource "aws_route_table_association" "subnet-1b" {
  subnet_id      = aws_subnet.subnet-1b.id
  route_table_id = aws_route_table.route-table.1.id
}

resource "aws_route_table_association" "subnet-1c" {
  subnet_id      = aws_subnet.subnet-1c.id
  route_table_id = aws_route_table.route-table.2.id
}

##############################################################
# Private NAT Route Tables Private fixed subnet associations #
##############################################################

resource "aws_route_table_association" "subnet-1a-fixed" {
  subnet_id      = aws_subnet.subnet-1a-fixed.id
  route_table_id = aws_route_table.route-table.0.id
}

resource "aws_route_table_association" "subnet-1b-fixed" {
  subnet_id      = aws_subnet.subnet-1b-fixed.id
  route_table_id = aws_route_table.route-table.1.id
}

resource "aws_route_table_association" "subnet-1c-fixed" {
  subnet_id      = aws_subnet.subnet-1c-fixed.id
  route_table_id = aws_route_table.route-table.2.id
}

###########################
# Private Linux instances #
###########################

resource "aws_instance" "linux" {
  count                       = var.linux_count
  ami                         = element(local.linux_image_private, count.index)
  instance_type               = element(local.linux_instance_type, count.index)
  subnet_id                   = element(local.subnets, count.index)
  associate_public_ip_address = false
  vpc_security_group_ids      = element(local.linux_security_groups, count.index)
  key_name                    = aws_key_pair.key.id
  iam_instance_profile        = element(local.linux_instance_profile, count.index)
  ebs_block_device {
    device_name           = "/dev/sdf"
    encrypted             = true
    volume_size           = element(local.linux_data_volume_size, count.index)
    volume_type           = "gp3"
    delete_on_termination = true
  }
  volume_tags = {
    Name = "${count.index + 1}"
  }
  tags = {
    Name        = element(local.linux_hostname, count.index)
    App         = element(local.linux_apps, count.index)
    FixedIP     = element(local.linux_fixed_ip, count.index)
    OsType      = element(local.linux_os_type, count.index)
    OsVer       = element(local.linux_os_ver, count.index)
    Monitor     = element(local.linux_monitor, count.index)
    OsPatch     = element(local.linux_patch, count.index)
    Environment = var.env
  }
}
###################
# Security Groups #
###################


# Note TCP = 6 / UDP = 17 - uses network frame protocol numbers
resource "aws_security_group" "private-sg" {
  vpc_id      = aws_vpc.vpc.id
  name        = "private-sg"
  description = "lf Private Security Group"

  # This allows devices inside the security group to talk freely.
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # DNS Access
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = 6
    cidr_blocks = ["10.0.0.0/8"]
  }
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = 17
    cidr_blocks = ["10.0.0.0/8"]
  }

  # This allows all outbound traffic to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Netbox
resource "aws_security_group" "netbox-sg" {
  vpc_id      = aws_vpc.vpc.id
  name        = "netbox-sg"
  description = "lf Netbox Security Group"

  # Netbox DEV Access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.lf_tgw_cidr]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.lf_tgw_cidr]
  }

}

# Calix inbound
resource "aws_security_group" "calix-sg" {
  vpc_id      = aws_vpc.vpc.id
  name        = "calix-sg"
  description = "lf Calix Security Group"

  # Calix DEV Access
  ingress {
    from_port   = 3443
    to_port     = 3443
    protocol    = "tcp"
    cidr_blocks = [var.lf_tgw_cidr]
  }

  ingress {
    from_port   = 18443
    to_port     = 18443
    protocol    = "tcp"
    cidr_blocks = [var.lf_tgw_cidr, "172.18.56.0/21"]
  }
}

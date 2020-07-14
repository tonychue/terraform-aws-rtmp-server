# Build VPC
resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  tags                 = merge(var.project_tags)
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
  tags   = merge(var.project_tags)
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.default.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

# Create a subnet to launch our instances into
resource "aws_subnet" "subnet" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Security groups
resource "aws_security_group" "ssh" {
  name        = "public ssh"
  description = "Security Group Deployment"
  vpc_id      = aws_vpc.default.id
  tags        = merge(var.project_tags)

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rtmp" {
  name        = "public rtmp and stat"
  description = "Security Group Deployment"
  vpc_id      = aws_vpc.default.id
  tags        = merge(var.project_tags)

  # rtmp access from anywhere
  ingress {
    from_port   = 1935
    to_port     = 1935
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "egress" {
  name        = "egress all"
  description = "Security Group Deployment"
  vpc_id      = aws_vpc.default.id
  tags        = merge(var.project_tags)

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.subnet.id
  vpc_security_group_ids = [
    aws_security_group.ssh.id,
    aws_security_group.rtmp.id,
    aws_security_group.egress.id
  ]
  user_data = data.cloudinit_config.cloudinit.rendered
  tags      = merge(var.project_tags)
  key_name  = var.key_name
}

resource "aws_eip" "ip_address" {
  instance = aws_instance.web.id
  vpc      = true
}

provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_vpc" "VPC" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "AND-Digital-VPC"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.VPC.id}"

  tags = {
    Name = "IG-Gateway"
  }
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "gw" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.PublicSubnetA.id}"

  tags = {
    Name = "NAT-Gw"
  }

  depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_default_route_table" "main-private-rt" {
  default_route_table_id = "${aws_vpc.VPC.default_route_table_id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.gw.id}"
  }

  tags = {
    Name = "main-private-RT"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = "${aws_vpc.VPC.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "public-RT"
  }
}

resource "aws_subnet" "PrivateSubnetA" {
  vpc_id            = "${aws_vpc.VPC.id}"
  cidr_block        = "10.0.0.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "Private-Subnet-A"
  }
}

resource "aws_subnet" "PrivateSubnetB" {
  vpc_id            = "${aws_vpc.VPC.id}"
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "Private-Subnet-B"
  }
}
resource "aws_subnet" "PrivateSubnetC" {
  vpc_id            = "${aws_vpc.VPC.id}"
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[2]

  tags = {
    Name = "Private-Subnet-C"
  }
}

resource "aws_subnet" "PublicSubnetA" {
  vpc_id                  = "${aws_vpc.VPC.id}"
  cidr_block              = "10.0.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-A"
  }
}

resource "aws_subnet" "PublicSubnetB" {
  vpc_id                  = "${aws_vpc.VPC.id}"
  cidr_block              = "10.0.4.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-B"
  }
}

resource "aws_subnet" "PublicSubnetC" {
  vpc_id                  = "${aws_vpc.VPC.id}"
  cidr_block              = "10.0.5.0/24"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-C"
  }
}

resource "aws_route_table_association" "PublicA" {
  subnet_id      = aws_subnet.PublicSubnetA.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "PublicB" {
  subnet_id      = aws_subnet.PublicSubnetB.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "PublicC" {
  subnet_id      = aws_subnet.PublicSubnetC.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "PrivateC" {
  subnet_id      = aws_subnet.PrivateSubnetC.id
  route_table_id = aws_vpc.VPC.main_route_table_id
}

resource "aws_route_table_association" "PrivateA" {
  subnet_id      = aws_subnet.PrivateSubnetA.id
  route_table_id = aws_vpc.VPC.main_route_table_id
}

resource "aws_route_table_association" "PrivateB" {
  subnet_id      = aws_subnet.PrivateSubnetB.id
  route_table_id = aws_vpc.VPC.main_route_table_id
}

resource "aws_security_group" "web_server" {
  name        = "allow_elb_http"
  description = "Allow HTTP traffic from ELB"
  vpc_id      = "${aws_vpc.VPC.id}"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.elb.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-SG"
  }
}

resource "aws_security_group" "elb" {
  name        = "allow_internet_http"
  description = "Allow HTTP traffic from anywhere"
  vpc_id      = "${aws_vpc.VPC.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "elb-SG"
  }
}

resource "aws_elb" "elb" {
  name            = "web-server-elb"
  subnets         = ["${aws_subnet.PublicSubnetA.id}", "${aws_subnet.PublicSubnetB.id}", "${aws_subnet.PublicSubnetC.id}"]
  security_groups = ["${aws_security_group.elb.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  instances                   = ["${aws_instance.WebServer1.id}", "${aws_instance.WebServer2.id}", "${aws_instance.WebServer3.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "web-server-elb"
  }
}

resource "aws_instance" "WebServer1" {
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.PrivateSubnetA.id}"
  associate_public_ip_address = false
  user_data                   = "${file("install_apache.sh")}"
  #key_name                    = "EC2KP"
  security_groups = ["${aws_security_group.web_server.id}"]

  tags = {
    Name = "Web-Server-1"
  }

  depends_on = ["aws_nat_gateway.gw"]
}

resource "aws_instance" "WebServer2" {
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.PrivateSubnetB.id}"
  associate_public_ip_address = false
  user_data                   = "${file("install_apache.sh")}"
  #key_name                    = "EC2KP"
  security_groups = ["${aws_security_group.web_server.id}"]

  tags = {
    Name = "Web-Server-2"
  }

  depends_on = ["aws_nat_gateway.gw"]
}

resource "aws_instance" "WebServer3" {
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.PrivateSubnetC.id}"
  associate_public_ip_address = false
  user_data                   = "${file("install_apache.sh")}"
  #key_name                    = "EC2KP"
  security_groups = ["${aws_security_group.web_server.id}"]

  tags = {
    Name = "Web-Server-3"
  }

  depends_on = ["aws_nat_gateway.gw"]
}




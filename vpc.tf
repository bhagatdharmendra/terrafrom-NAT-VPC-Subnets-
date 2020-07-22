provider "aws" {
  region     = "ap-south-1"
   profile = "eks"
}

resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "sonu-vpc"
  }
}

resource "aws_subnet" "subnet-1" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "public-sonu-vpc-subnet"
  }
}

resource "aws_subnet" "subnet-2" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "private-sonu-vpc-subnet"
  }
}
######### public SG
resource "aws_security_group" "allow_tls" {
  name        = "public_sonu_vpc"
  description = "ssh,http"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
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
    Name = "public_sonu_vpc_SG"
  }
}
######### private SG
resource "aws_security_group" "allow_tls2" {
  name        = "private_sonu_vpc"
  description = "ssh,http for private access only "
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [ "${aws_security_group.allow_tls.id}" ]
  }
   ingress {
    description = "mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [ "${aws_security_group.allow_tls.id}" ]
  }
   ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [ "${aws_security_group.allow_tls.id}" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private_sonu_vpc_SG"
  }
  
}
##### Internet Gateways
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "sonu-vpc-gateways"
  }
}
##### routing tables #######
resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

   tags = {
    Name = "public_routing_tables"
  }
  depends_on = [
    aws_internet_gateway.gw
  ]
}

######## subnet association###
resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.subnet-1.id}"
  route_table_id = "${aws_route_table.r.id}"
  
  depends_on = [
    aws_subnet.subnet-1
       
  ]

}


 
######### Launch EC2-instance  in public instance ######  

resource "aws_instance" "instance1" {
  ami           = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ "${aws_security_group.allow_tls.id}" ]
  associate_public_ip_address = true
  subnet_id = "${aws_subnet.subnet-1.id}"
  key_name = "hybrid-multi-cloud-sonuBhagta"
  
  
  
  tags = {
    Name = "wordpress-public"
  }
 
}

###########

########### NAT #######

resource "aws_eip" "byoip-ip" {
  vpc              = true
  public_ipv4_pool = "amazon"
}
resource "aws_nat_gateway" "gw" {
  allocation_id = "${aws_eip.byoip-ip.id}"
  subnet_id     = "${aws_subnet.subnet-1.id}"
}
##### routing tables #######
resource "aws_route_table" "nat" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.gw.id}"
  }

   tags = {
    Name = "private_routing_tables"
  }
  depends_on = [
    aws_nat_gateway.gw
  ]
} 

######## subnet association with private subnet ###
resource "aws_route_table_association" "routetable" {
  subnet_id      = "${aws_subnet.subnet-2.id}"
  route_table_id = "${aws_route_table.nat.id}"
  
  depends_on = [
    aws_subnet.subnet-2
       
  ]

}
######### Launch EC2-instance  in private instance ######  

resource "aws_instance" "instance2" {
  ami           = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ "${aws_security_group.allow_tls2.id}" ]
  associate_public_ip_address = false 
  subnet_id = "${aws_subnet.subnet-2.id}"
  key_name = "hybrid-multi-cloud-sonuBhagta"
   
  
  tags = {
    Name = "mysql-server-private"
  }
 
}
output "WordPress_IP-instance-1" {
  value = aws_instance.instance1.public_ip
}
output "MySQL_IP-instance-2" {
  value = aws_instance.instance2.private_ip
}
#############

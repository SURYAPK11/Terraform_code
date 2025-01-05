terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "my-vpc"
  }
}

 resource "aws_subnet" "publicsubnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "pub-sub"
  }
}

 resource "aws_subnet" "privatesubnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "pvt-sub"
  }
}

 resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "aws-igw"
  }
}

resource "aws_route_table" "publicrtb" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "my-pub-rtb"
  }
}

resource "aws_route_table_association" "pubrtbasso" {
  subnet_id      = aws_subnet.publicsubnet.id
  route_table_id = aws_route_table.publicrtb.id
}

resource "aws_eip" "myeip" {  
  vpc      = true
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.myeip.id
  subnet_id     = aws_subnet.publicsubnet.id

  tags = {
    Name = "vpc-nat-gw"
  }
}

resource "aws_route_table" "privatertb" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "my-pvt-rtb"
  }
}

resource "aws_route_table_association" "pvtrtbasso" {
  subnet_id      = aws_subnet.privatesubnet.id
  route_table_id = aws_route_table.privatertb.id
}

resource "aws_security_group" "pubsg" {
  name        = "pubsg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "ALLOW HTTPS traffic"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }


  ingress {
    description      = "ALLOW ALL traffic"
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]    
  }
}

resource "aws_security_group" "pvtsg" {
  name        = "pvtsg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "ALLOW HTTPS traffic"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["10.0.1.0/24"]    
 }

  ingress {
    description      = "Allow SSH traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["10.0.1.0/24"]    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "pubinstance" {
  ami                                             = "ami-0dee22c13ea7a9a67"
  instance_type                                   = "t2.micro"
  subnet_id                                       = aws_subnet.publicsubnet.id
  vpc_security_group_ids                          = [aws_security_group.pubsg.id]
  key_name                                        = "24_10"
  associate_public_ip_address                     = "true"
}

resource "aws_instance" "pvtinstance" {
  ami                                             = "ami-0dee22c13ea7a9a67"
  instance_type                                   = "t2.micro"
  subnet_id                                       = aws_subnet.privatesubnet.id
  vpc_security_group_ids                          = [aws_security_group.pvtsg.id]
  key_name                                        = "24_10"
}



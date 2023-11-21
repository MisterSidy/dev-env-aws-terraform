resource "aws_vpc" "sap-vpc" {
  cidr_block           = "10.16.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}
resource "aws_subnet" "sap-public-subnet" {
  vpc_id                  = aws_vpc.sap-vpc.id
  cidr_block              = "10.16.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "dev-public"
  }
}
resource "aws_internet_gateway" "sap-internet_gateway" {
  vpc_id = aws_vpc.sap-vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "sap-public-rt" {
  vpc_id = aws_vpc.sap-vpc.id

  tags = {
    Name = "dev-public-rt"
  }
}

resource "aws_route" "sap-default-route" {
  route_table_id         = aws_route_table.sap-public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.sap-internet_gateway.id

}

resource "aws_route_table_association" "sap-public-sap" {
  subnet_id      = aws_subnet.sap-public-subnet.id
  route_table_id = aws_route_table.sap-public-rt.id
}

resource "aws_security_group" "sap-sg" {
    name = "dev-sg"
    description = "dev security group"
    vpc_id = aws_vpc.sap-vpc.id

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
      Name = "dev-sg"
    }
  
}
#  ssh-keygen -t ed25519         ls ~/.ssh

resource "aws_key_pair" "sap-auth" {
    key_name = "sapkey"
    public_key = file("~/.ssh/sapkey.pub")
  
}

resource "aws_instance" "dev-node" {
    instance_type = "t2.micro"
    ami = data.aws_ami.server_ami.id
    key_name = aws_key_pair.sap-auth.id
    vpc_security_group_ids = [ aws_security_group.sap-sg.id ]
    subnet_id = aws_subnet.sap-public-subnet.id
    user_data = file("userdata.tpl")

    root_block_device {
      volume_size = 10
    }

    tags = {
      Name = "dev-server"
    }

    provisioner "local-exec" {
      # on_failure = continue
      command = templatefile("${var.host_os}-ssh-config.tpl",{
        hostname = self.public_ip,
        user = "ubuntu",
        identityfile = "~/.ssh/sapkey"
      })
      interpreter = var.host_os == "windows" ? [ "Powershell", "-Command" ] : [ "bash", "-c" ]
    }


}
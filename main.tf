##### Variables

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}

variable "key_name" {
  default = "beto-aws-key-us-east-1"
}

####### Providers ######
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-1"
}

######## Data ######

data "aws_availability_zones" "available" {}

#####################
######## Resoruces
#####################

#Networking

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name            = "beto-apache-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["us-east-1a"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.50.0/24"]

  enable_nat_gateway           = false
  enable_vpn_gateway           = false
  create_database_subnet_group = false

  tags = {
    Terraform   = "true"
    Environment = "beto"
  }
}

# Apache security group
resource "aws_security_group" "apache-sg" {
  name   = "apache_sg"
  vpc_id = "${module.vpc.vpc_id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "beto-apache-sg"
    Environment = "beto-env"
  }
}

### EC2 ###
resource "aws_instance" "web" {
  ami                    = "ami-759bc50a"
  instance_type          = "t2.micro"
  subnet_id              = "${element(module.vpc.public_subnets, 0)}"
  vpc_security_group_ids = ["${aws_security_group.apache-sg.id}"]
  key_name               = "${var.key_name}"

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sleep 10",
      "sudo apt-get install apache2 -y",
      "sudo service apache2 start",
    ]
  }

  tags {
    Name = "beto-apache"
  }
}

########## OUTPUTS

output "aws_instance_public_ip" {
  value = "${aws_instance.web.public_ip}"
}

output "module_vpc_id" {
  value = "${module.vpc.vpc_id}"
}
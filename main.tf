# Terraform AWS Provider - https://registry.terraform.io/providers/hashicorp/aws/latest/docs

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure options
provider "aws" {
  region = "us-east-1"
}

# Defile any local vars
locals {
  pem_file = "~/.ssh/cp_k8s_kp.pem"
  key_name = "cp_k8s_kp"
}


# https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key
resource "tls_private_key" "rsa_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair
resource "aws_key_pair" "cp_k8s_ec2_key_pair" {
  key_name   = local.key_name
  public_key = tls_private_key.rsa_key.public_key_openssh

  provisioner "local-exec" {
    command = <<-EOT
      rm -rf ${local.pem_file}
      echo '${tls_private_key.rsa_key.private_key_pem}' > ${local.pem_file}
      chmod 400 ${local.pem_file}
      ls -l ${local.pem_file} > /tmp/out
    EOT
  }
}

resource "aws_vpc" "cp_k8s_vpc" {
  cidr_block           = "11.0.0.0/22"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "cp_k8s_VPC"
  }
}

resource "aws_subnet" "cp_k8s_subnet" {
  vpc_id            = aws_vpc.cp_k8s_vpc.id
  cidr_block        = "11.0.0.0/24"
  availability_zone = var.availability_zone

  tags = {
    Name = "cp_k8s_subnet"
  }
}

resource "aws_internet_gateway" "cp_k8s_igw" {
  vpc_id = aws_vpc.cp_k8s_vpc.id
  tags = {
    Name = "cp_k8s_igw"
  }
}


/* Routing table for public subnet */
resource "aws_route_table" "cp_k8s_public_route_table" {
  depends_on = [
    aws_subnet.cp_k8s_subnet
  ]
  vpc_id = aws_vpc.cp_k8s_vpc.id
  tags = {
    Name = "cp_k8s_public_route_table"
  }
}
resource "aws_route" "cp_k8s_public_route" {
  depends_on = [
    aws_route_table.cp_k8s_public_route_table
  ]
  route_table_id         = aws_route_table.cp_k8s_public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.cp_k8s_igw.id
}

resource "aws_route_table_association" "cp_k8s_public_subnet_association" {
  depends_on = [
    aws_route.cp_k8s_public_route
  ]
  subnet_id      = aws_subnet.cp_k8s_subnet.id
  route_table_id = aws_route_table.cp_k8s_public_route_table.id
}

resource "aws_security_group" "cp_k8s_ec2_sg_control_plane" {
  name        = "cp-sg-kube-control"
  vpc_id      = aws_vpc.cp_k8s_vpc.id
  description = "Allow SSH inbound traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.sg_control_plane_tags
}

resource "aws_security_group" "cp_k8s_ec2_sg_worker_nodes" {
  name        = "cp-sg-kube-worker"
  vpc_id      = aws_vpc.cp_k8s_vpc.id
  description = "Allow SSH inbound traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TCP"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.sg_worker_node_tags
}

resource "aws_security_group_rule" "cp_to_worker_nodes" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.cp_k8s_ec2_sg_worker_nodes.id
  source_security_group_id = aws_security_group.cp_k8s_ec2_sg_control_plane.id
}

resource "aws_security_group_rule" "worker_nodes_to_cp" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.cp_k8s_ec2_sg_control_plane.id
  source_security_group_id = aws_security_group.cp_k8s_ec2_sg_worker_nodes.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
resource "aws_instance" "cp_k8s_ec2_instance_control_plane_node" {
  depends_on = [
    aws_subnet.cp_k8s_subnet
  ]
  ami                         = var.ami_id
  subnet_id                   = aws_subnet.cp_k8s_subnet.id
  instance_type               = var.cp_instance_type
  key_name                    = aws_key_pair.cp_k8s_ec2_key_pair.key_name
  private_ip                  = "11.0.0.10"
  vpc_security_group_ids      = [aws_security_group.cp_k8s_ec2_sg_control_plane.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = "k8s-control-plane-node"
    # Schedule = "stop_when_I_sleep"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.rsa_key.private_key_openssh
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    scripts = [
      "./kubeadm-scripts/step-01-k8s-packages.sh",
      # "./kubeadm-scripts/step-02-k8s-cp-init.sh",
    ]
  }
  # provisioner "local-exec" {
  #   command = <<-EOT
  #     join_cmd=$(ssh ec2-user@${self.public_ip} -o StrictHostKeyChecking=no -i ${local.pem_file} "kubeadm token create --print-join-command")
  #     rm -rf ./kubeadm-scripts/step-03-k8s-join.sh
  #     echo "sudo $join_cmd"  > ./kubeadm-scripts/step-03-k8s-join.sh
  #   EOT
  # }
}

# resource "aws_network_interface" "eni" {
#   subnet_id   = aws_subnet.my_subnet.id
#   private_ips = ["172.16.10.100"]

#   tags = {
#     Name = "primary_network_interface"
#   }
# }


resource "aws_instance" "cp_k8s_ec2_instance_worker_node" {
  depends_on = [
    aws_instance.cp_k8s_ec2_instance_control_plane_node
  ]

  for_each = { for idx, worker_node in var.worker_nodes : idx => worker_node }

  ami                         = var.ami_id
  subnet_id                   = aws_subnet.cp_k8s_subnet.id
  instance_type               = var.worker_node_instance_type
  key_name                    = aws_key_pair.cp_k8s_ec2_key_pair.key_name
  private_ip                  = each.value.private_ip
  vpc_security_group_ids      = [aws_security_group.cp_k8s_ec2_sg_worker_nodes.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
  }

  tags = merge(
    { Name = each.value.Name },
    var.worker_node_tags
  )

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.rsa_key.private_key_openssh
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    scripts = [
      "./kubeadm-scripts/step-01-k8s-packages.sh",
      # "./kubeadm-scripts/step-03-k8s-join.sh",
    ]
  }
}

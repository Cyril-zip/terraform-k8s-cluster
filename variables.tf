# variable "my_public_ip" {
#   description = "Enter your public IP. Run 'curl ifconfig.me' is one way to find out."
#   type        = string
# }

variable "worker_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "control_plane_node_tags" {
  description = "Tags for Control Plane node instance"
  type        = map(string)
  default = {
    Name = "k8s-control-plane-node"
    # Schedule = "stop_when_I_sleep"
  }
}

variable "worker_nodes" {
  type = list(map(string))
  default = [
    {
      Name       = "k8s-worker-node-1",
      private_ip = "10.0.0.11"
    },
    {
      Name       = "k8s-worker-node-2",
      private_ip = "10.0.0.12"
    },
    {
      Name       = "k8s-worker-node-3",
      private_ip = "10.0.0.13"
    }
  ]
}


variable "worker_node_tags" {
  description = "Tags for Control Plane node instance"
  type        = map(string)
  default = {
    Schedule = "stop_when_I_sleep"
  }
}

variable "ami_id" {
  description = "AMI used for the EC2 instances"
  type        = string
  default     = "ami-0a0e5d9c7acc336f1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"
}

variable "sg_worker_node_tags" {
  description = "Tags for Security Group (Worker node)"
  type        = map(string)
  default = {
    Name = "k8s-cluster-worker"
  }
}

variable "sg_control_plane_tags" {
  description = "Tags for Security Group (Control plane node)"
  type        = map(string)
  default = {
    Name = "k8s-cluster-control-plane"
  }
}

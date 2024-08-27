output "node_dns_info" {

  value = [
    for ec2 in concat([aws_instance.cp_k8s_ec2_instance_control_plane_node], values(aws_instance.cp_k8s_ec2_instance_worker_node)) : {
      ssh_cmd = ec2.tags["Name"] == "k8s-control-plane-node" ? "${ec2.tags["Name"]} : ssh -i ${local.pem_file} ubuntu@${ec2.public_dns} ; Run 'kubectl get nodes' to test cluster is up!" : "${ec2.tags["Name"]} : ssh -i ${local.pem_file} ubuntu@${ec2.public_dns}"
    }
  ]
  description = "Cluster Node DNS and IPs"
}

#!/bin/bash
sudo hostnamectl set-hostname "k8smaster.example.net"
# sudo hostnamectl set-hostname "k8sworker1.example.net" && exec bash
# sudo hostnamectl set-hostname "k8sworker2.example.net" && exec bash
# sudo hostnamectl set-hostname "k8sworker3.example.net" && exec bash

sudo apt update && sudo apt install net-tools -y

sudo tee -a /etc/hosts <<EOF
# k8s nodes
10.0.0.10 k8smaster.example.net k8smaster
10.0.0.11 k8sworker1.example.net k8sworker1
10.0.0.12 k8sworker2.example.net k8sworker2
10.0.0.13 k8sworker3.example.net k8sworker3
EOF

sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

sudo apt update
sudo apt install -y containerd.io

containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list


sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo kubeadm join k8smaster.example.net:6443 --token slufsr.crc8unc1d0hgphwn \
        --discovery-token-ca-cert-hash sha256:d619ede39f82b0dedf4975eb4924fbb7c2e6b818c394e91c43acf85bbc7797d7
#!/bin/bash

# Migrate the kubeadm configuration
kubeadm config migrate --old-config kubeadm-init-config.yml --new-config kubeadm-init-config.yml

# Initialize the Kubernetes cluster
sudo kubeadm init --config kubeadm-init-config.yml

# Configure kubectl for the current user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
# Configure kubectl for root user
sudo su -c 'echo "export KUBECONFIG=$HOME/.kube/config" >> ~/.bashrc'
sudo su -c 'source ~/.bashrc'

# Clone the AWS cloud provider repository and apply the configuration
git clone https://github.com/kubernetes/cloud-provider-aws.git
kubectl apply -k cloud-provider-aws/examples/existing-cluster/base

# Apply the Calico network manifest
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Generate the join command for worker nodes
JOIN_CMD=$(sudo kubeadm token create --print-join-command)

# Generate the certificate key for master nodes
CERT_KEY=$(sudo kubeadm init phase upload-certs --upload-certs | tail -1)

# Create the master and worker join commands
MASTER_JOIN_CMD="sudo $JOIN_CMD --control-plane --certificate-key $CERT_KEY"
WORKER_JOIN_CMD="sudo $JOIN_CMD"

# Print the join commands
echo "Master Join Command:"
echo "$MASTER_JOIN_CMD"

echo "Worker Join Command:"
echo "$WORKER_JOIN_CMD"

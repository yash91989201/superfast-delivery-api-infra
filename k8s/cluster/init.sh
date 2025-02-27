#!/bin/bash

MASTER1_DNS=$(hostname)
LB_DNS=$(aws elbv2 describe-load-balancers | jq -r '.LoadBalancers[].LoadBalancerArn' |
  xargs -I {} aws elbv2 describe-tags --resource-arns {} --query "TagDescriptions[?Tags[?Key=='k8s-api-server-lb' && Value=='true']].ResourceArn" --output text |
  xargs -I {} aws elbv2 describe-load-balancers --load-balancer-arns {} --query "LoadBalancers[0].DNSName" --output text)

sed -i "s/LB_DNS/${LB_DNS}/g; s/MASTER1_DNS/${MASTER1_DNS}/g" config.yml

# Migrate the kubeadm configuration
kubeadm config migrate --old-config config.yml --new-config config.yml

# Initialize the Kubernetes cluster
sudo kubeadm init --config config.yml

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

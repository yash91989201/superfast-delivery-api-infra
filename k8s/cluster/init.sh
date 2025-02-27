#!/bin/bash

LB_DNS=""
PORT=6443
MASTER1_DNS=$(hostname)

while [[ -z "$LB_DNS" ]]; do
  LB_DNS=$(aws elbv2 describe-load-balancers | jq -r '.LoadBalancers[].LoadBalancerArn' |
    xargs -I {} aws elbv2 describe-tags --resource-arns {} --query "TagDescriptions[?Tags[?Key=='k8s-api-server-lb' && Value=='true']].ResourceArn" --output text |
    xargs -I {} aws elbv2 describe-load-balancers --load-balancer-arns {} --query "LoadBalancers[0].DNSName" --output text)

  if [[ -z "$LB_DNS" ]]; then
    echo "Waiting for load balancer DNS..."
    sleep 5
  fi
done

sed -i "s/LB_DNS/${LB_DNS}/g; s/MASTER1_DNS/${MASTER1_DNS}/g" config.yml

# Migrate the kubeadm configuration
kubeadm config migrate --old-config config.yml --new-config config.yml

# Initialize the Kubernetes cluster
sudo kubeadm init --config config.yml

# Configure kubectl for the current user
mkdir -p /home/ubuntu/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown -R ubuntu:ubuntu /home/ubuntu/.kube
# Configure kubectl for root user
echo "export KUBECONFIG=/.kube/config" >>/.bashrc
source /.bashrc

sleep 2m
# Clone the AWS cloud provider repository and apply the configuration
git clone https://github.com/kubernetes/cloud-provider-aws.git
kubectl apply --validate=false -k cloud-provider-aws/examples/existing-cluster/base

# Apply the Calico network manifest
kubectl apply --validate=false -f https://docs.projectcalico.org/manifests/calico.yaml

# Generate the join command for worker nodes
JOIN_CMD=$(sudo kubeadm token create --print-join-command)

# Generate the certificate key for master nodes
CERT_KEY=$(sudo kubeadm init phase upload-certs --upload-certs | tail -1)

# Create the master and worker join commands
MASTER_JOIN_CMD="sudo $JOIN_CMD --control-plane --certificate-key $CERT_KEY"
WORKER_JOIN_CMD="sudo $JOIN_CMD"

echo "$MASTER_JOIN_CMD" >/home/ubuntu/master-join-cmd
echo "$WORKER_JOIN_CMD" >/home/ubuntu/worker-join-cmd

# Print the join commands
echo "Master Join Command:"
echo "$MASTER_JOIN_CMD"

echo "Worker Join Command:"
echo "$WORKER_JOIN_CMD"

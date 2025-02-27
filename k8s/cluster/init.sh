#!/bin/bash

LB_DNS=""
MASTER1_DNS=$(hostname)

while [[ -z "$LB_DNS" ]]; do
  # Fetch load balancer ARN with the required tag
  LB_ARN=$(aws elbv2 describe-load-balancers | jq -r '.LoadBalancers[].LoadBalancerArn' |
    xargs -I {} aws elbv2 describe-tags --resource-arns {} --query "TagDescriptions[?Tags[?Key=='k8s-api-server-lb' && Value=='true']].ResourceArn" --output text)

  if [[ -n "$LB_ARN" ]]; then
    # Check if load balancer is active
    LB_STATE=$(aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" --query "LoadBalancers[0].State.Code" --output text)

    if [[ "$LB_STATE" == "active" ]]; then
      # Get DNS name if active
      LB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" --query "LoadBalancers[0].DNSName" --output text)
    else
      echo "Load balancer is not active yet. Waiting..."
    fi
  else
    echo "Load balancer ARN not found. Waiting..."
  fi

  if [[ -z "$LB_DNS" ]]; then
    sleep 5
  fi
done

nc -zv $LB_DNS 6443

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

# wait for some time so that the worker node 1 is ready
sleep 4m

kubectl get nodes

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

echo "$MASTER_JOIN_CMD" >/home/ubuntu/master-join-cmd
echo "$WORKER_JOIN_CMD" >/home/ubuntu/worker-join-cmd

# Print the join commands
echo "Master Join Command:"
echo "$MASTER_JOIN_CMD"

echo "Worker Join Command:"
echo "$WORKER_JOIN_CMD"

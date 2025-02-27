#!/bin/bash

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Fetch the private DNS name from instance metadata
NODE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)
DNS_NAME=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-hostname)

# Set the hostname dynamically
hostnamectl set-hostname "$DNS_NAME"

# Prevent CloudInit from resetting the hostname on reboot
echo "preserve_hostname: true" | sudo tee -a /etc/cloud/cloud.cfg >/dev/null

echo "KUBELET_EXTRA_ARGS='--cloud-provider=external --node-ip=$NODE_IP'" >/etc/default/kubelet

# Restart kubelet to apply changes
sudo systemctl daemon-reload
sudo systemctl restart kubelet

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

git clone https://github.com/yash91989201/superfast-delivery-api-infra /home/ubuntu/superfast-delivery-api-infra
chown -R ubuntu:ubuntu /home/ubuntu/superfast-delivery-api-infra

cd /home/ubuntu/superfast-delivery-api-infra/k8s/cluster

chmod 700 init.sh

./init.sh

MASTER_JOIN_CMD=$(cat "/home/ubuntu/master-join-cmd")
WORKER_JOIN_CMD=$(cat "/home/ubuntu/worker-join-cmd")

aws ssm put-parameter --name "/k8s/join/master" --value "$MASTER_JOIN_CMD" --type "SecureString" --overwrite
aws ssm put-parameter --name "/k8s/join/worker" --value "$WORKER_JOIN_CMD" --type "SecureString" --overwrite

echo "Waiting for at least 3 ready nodes..."

while true; do
  # Count nodes in 'Ready' state
  READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready")

  if [[ $READY_NODES -ge 3 ]]; then
    echo "Cluster has $READY_NODES ready nodes. Exiting..."
    exit 0
  fi

  echo "Current ready nodes: $READY_NODES. Retrying in 5 seconds..."
  sleep 5
done

cd /home/ubuntu/superfast-delivery-api-infra/k8s/cluster/setup

chmod 700 install.sh

./install.sh

cd /home/ubuntu/superfast-delivery-api-infra/k8s/cluster/apps

chmod 700 install.sh

./install.sh

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

apt install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

git clone https://github.com/yash91989201/superfast-delivery-api-infra /home/ubuntu/superfast-delivery-api-infra
chown -R ubuntu:ubuntu /home/ubuntu/superfast-delivery-api-infra

cd /home/ubuntu/superfast-delivery-api-infra/k8s/cluster

chmod 700 init.sh

sleep 2m

./init.sh

MASTER_JOIN_CMD=$(cat "/home/ubuntu/master-join-cmd")
WORKER_JOIN_CMD=$(cat "/home/ubuntu/worker-join-cmd")

aws ssm put-parameter --name "/k8s/join/master" --value "$MASTER_JOIN_CMD" --type "SecureString" --overwrite
aws ssm put-parameter --name "/k8s/join/worker" --value "$WORKER_JOIN_CMD" --type "SecureString" --overwrite

cd /home/ubuntu/superfast-delivery-api-infra/k8s/cluster/setup

chmod 700 install.sh

./install.sh

cd /home/ubuntu/superfast-delivery-api-infra/k8s/cluster/apps

chmod 700 install.sh

./install.sh

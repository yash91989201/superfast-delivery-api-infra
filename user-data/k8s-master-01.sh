#!/bin/bash

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Fetch the private DNS name from instance metadata
DNS_NAME=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-hostname)

# Set the hostname dynamically
hostnamectl set-hostname "$DNS_NAME"

# Prevent CloudInit from resetting the hostname on reboot
echo "preserve_hostname: true" | sudo tee -a /etc/cloud/cloud.cfg >/dev/null

# File path for kubelet config
KUBELET_CONFIG="/etc/default/kubelet"

# Check if the file exists, if not, create it
if [ ! -f "$KUBELET_CONFIG" ]; then
  echo "Creating $KUBELET_CONFIG"
  echo "KUBELET_EXTRA_ARGS='--cloud-provider=external'" | sudo tee "$KUBELET_CONFIG"
else
  # If the line exists, update it. If not, append it.
  if grep -q "KUBELET_EXTRA_ARGS=" "$KUBELET_CONFIG"; then
    sudo sed -i 's|^KUBELET_EXTRA_ARGS=.*|KUBELET_EXTRA_ARGS="--cloud-provider=external"|' "$KUBELET_CONFIG"
  else
    echo "KUBELET_EXTRA_ARGS='--cloud-provider=external'" | sudo tee -a "$KUBELET_CONFIG"
  fi
fi

# Restart kubelet to apply changes
sudo systemctl daemon-reload
sudo systemctl restart kubelet

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

git clone https://github.com/yash91989201/superfast-delivery-api-infra /home/ubuntu/superfast-delivery-api-infra

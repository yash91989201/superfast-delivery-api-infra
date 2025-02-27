#!/bin/bash

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Fetch the private DNS name from instance metadata
NODE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)
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
  echo "KUBELET_EXTRA_ARGS='--cloud-provider=external --node-ip=$NODE_IP'" | sudo tee "$KUBELET_CONFIG"
else
  # Update the line to include --node-ip
  sudo sed -i "s|--cloud-provider=external|--cloud-provider=external --node-ip=$NODE_IP|g" "$KUBELET_CONFIG"
fi

# Restart kubelet to apply changes
sudo systemctl daemon-reload
sudo systemctl restart kubelet

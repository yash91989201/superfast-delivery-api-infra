#!/bin/bash
set -e

# Write private key with proper formatting
cat <<EOF >/home/ubuntu/k8s-master-key.pem
{{K8S_SSH_PRIVATE_KEY}}
EOF

# Fix permissions and ownership
chmod 600 /home/ubuntu/k8s-master-key.pem
chown ubuntu:ubuntu /home/ubuntu/k8s-master-key.pem

#!/bin/bash
set -e

echo "{{K8S_SSH_KEY}}" >k8s-master-key.pem

chmod 600 k8s-master-key.pem

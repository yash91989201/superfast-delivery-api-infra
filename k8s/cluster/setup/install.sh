#!/bin/bash

HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name yashraj-jaiswal.site --query "HostedZones[0].Id" --output text | cut -d'/' -f3)

sed -i "s/HOSTED_ZONE_ID/$HOSTED_ZONE_ID/g" external-dns/values.yml

# Create required namespaces
kubectl create ns traefik
kubectl create ns cert-manager

# Clone the AWS cloud provider repository and apply the configuration
git clone https://github.com/kubernetes/cloud-provider-aws.git
kubectl apply -k cloud-provider-aws/examples/existing-cluster/base

# Apply the Calico network manifest
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.40"

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns

helm repo add jetstack https://charts.jetstack.io

helm repo add traefik https://helm.traefik.io/traefik

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server

# Installations
helm upgrade --install external-dns external-dns/external-dns -n kube-system -f external-dns/values.yml

kubectl apply -f storageclass/manifest.yml

helm upgrade -i cert-manager jetstack/cert-manager -n cert-manager -f cert-manager/values.yml

helm upgrade -i traefik traefik/traefik -n traefik -f traefik/values.yml

helm install metrics-server metrics-server/metrics-server -n kube-system --set args={--kubelet-insecure-tls}

kubectl apply -f cert-manager/clusterissuer-staging.yml

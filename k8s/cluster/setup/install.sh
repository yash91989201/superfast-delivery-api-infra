#!/bin/bash

kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.40"

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns

helm repo add jetstack https://charts.jetstack.io

helm repo add traefik https://helm.traefik.io/traefik

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server

# Create required namespaces
kubectl create ns traefik
kubectl create ns cert-manager

# Installations
helm upgrade --install external-dns external-dns/external-dns -n kube-system -f external-dns/values.yml

kubectl apply -f storageclass/manifest.yml

helm upgrade -i cert-manager jetstack/cert-manager -n cert-manager -f cert-manager/values.yml

helm upgrade -i traefik traefik/traefik -n traefik -f traefik/values.yml

helm upgrade --install metrics-server metrics-server/metrics-server

kubectl apply -f cert-manager/clusterissuer-staging.yml

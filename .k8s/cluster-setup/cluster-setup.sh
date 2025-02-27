#!/bin/bash

kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.40"

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns

helm repo add jetstack https://charts.jetstack.io

helm repo add traefik https://helm.traefik.io/traefik

# Create required namespaces
kubectl create ns argocd
kubectl create ns traefik
kubectl create ns cert-manager

# Installations
helm upgrade --install external-dns external-dns/external-dns -n kube-system -f external-dns/values.yml

kubectl apply -f storageclass/manifest.yml

helm upgrade -i cert-manager jetstack/cert-manager -n cert-manager --create-namespace -f cert-manager/values.yml

helm upgrade -i traefik traefik/traefik -n traefik -f traefik/values.yml

kubectl apply -f cluster-setup/clusterissuer-staging.yml

kubectl apply -f traefik/acme-http-solver.yml

# Steup traefik dashboard
cd traefik-dashboard
kubectl apply -f secret.yml -f middleware.yml -f certificate.yml -f ingressroute.yml

# Steup k8s-dashboard
cd ../k8s-dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl apply -f middleware.yml -f certificate.yml -f ingressroute.yml -f cluster-role-binding.yml -f service-account.yml
# create k8s dashboard token
kubectl -n kubernetes-dashboard create token admin-user

# Steup argocd
cd ../argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f middleware.yml -f certificate.yml -f ingressroute.yml
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

cd ..

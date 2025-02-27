#!/bin/bash
# Create required namespaces
kubectl create ns argocd
kubectl create ns headlamp
#
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
#
helm repo add headlamp https://headlamp-k8s.github.io/headlamp
helm install headlamp headlamp/headlamp -n headlamp
#
kubectl apply -f traefik-dashboard.yml
#
kubectl apply -f headlamp.yml
#
kubectl apply -f argocd.yml

kubectl apply -f headlamp.yml

echo "Headlamp Admin Token:"
kubectl get secret headlamp-admin-token -n kube-system -o jsonpath='{.data.token}' | base64 --decode && echo

echo "Argocd Initial Admin Secret"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

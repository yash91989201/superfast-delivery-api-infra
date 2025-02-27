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

sleep 1m
#
kubectl create serviceaccount headlamp-admin -n headlamp
kubectl create clusterrolebinding headlamp-admin --serviceaccount=headlamp:headlamp-admin --clusterrole=cluster-admin
kubectl create token headlamp-admin -n headlamp --duration=0

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

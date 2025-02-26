#!/bin/bash

kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.40"

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns

helm repo add jetstack https://charts.jetstack.io

helm repo add traefik https://helm.traefik.io/traefik

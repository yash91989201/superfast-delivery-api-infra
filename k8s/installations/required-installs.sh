helm repo add external-dns https://kubernetes-sigs.github.io/external-dns
helm upgrade --install external-dns external-dns/external-dns -n kube-system -f external-dns-values.yml

kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.40"
kubectl apply -f storageclass.yml

helm repo add jetstack https://charts.jetstack.io
helm upgrade -i cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.17.1 -f cert-manager-values.yml

helm repo add traefik https://helm.traefik.io/traefik
helm upgrade -i traefik traefik/traefik -n traefik --create-namespace -f traefik-values.yml

kubectl apply -f traefik-cluster-issuer-staging.yml

kubectl apply -f traefik-dashboard-certificate.yml

kubectl apply -f traefik-dashboard-creds.yml

kubectl apply -f traefik-dashboard-middlewares.yml

kubectl apply -f traefik-dashboard-ingress-route.yml

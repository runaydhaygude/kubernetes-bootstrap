#!/bin/bash

# Set environment variables
export NAME=runay


kubectl create namespace metrics

# Setup cluster autoscaler

# kubectl -n kube-system get deployment -o name \
#     | grep "cluster-autoscaler" \
#     | xargs -I{} kubectl -n kube-system rollout status {}



# Setup metrics server
# if ! helm repo list | grep -q 'metrics-server'; then
#     helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
# fi

# kubectl create namespace metrics

# helm install metrics-server metrics-server/metrics-server -f ../monitoring/metrics-server-local.yaml -n metrics


# kubectl -n metrics \
#     rollout status \
#     deployment metrics-server


# Install Ingress 
if ! helm repo list | grep -q 'ingress-nginx'; then
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
fi

kubectl create namespace ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx

## Wait until the ingress-nginx controller pods are ready
echo "Waiting for ingress-nginx controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=Available \
  --timeout=300s deployment/ingress-nginx-controller

echo "Ingress controller is ready."


# LB Ip
echo "LB_IP=localhost"

# mkdir -p /data/volumes/pv1
# chmode 777 /data/volumes/pv1

# OpenEBS for dynamic provisioner for local storage
## Make sure to have udev dir created at ~/.docker/run 
# mkdir -p ~/.docker/run/udev
# kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml

# Create custom storage class
# kubectl apply -f - <<EOF
# apiVersion: storage.k8s.io/v1
# kind: StorageClass
# metadata:
#   name: custom-gp3
# provisioner: openebs.io/local
# volumeBindingMode: WaitForFirstConsumer
# reclaimPolicy: Delete
# EOF


# Setup local storage
kubectl apply -f persistent-volume-local.yaml


# Setup Prometheus

# Define the entries to be added
HOST_ENTRIES=(
  "127.0.0.1    mon.localhost"
  "127.0.0.1    alertmanager.localhost"
  "127.0.0.1    grafana.localhost"
)

# Check and append each entry if it doesn't already exist
for entry in "${HOST_ENTRIES[@]}"; do
  if ! grep -qF "$entry" /etc/hosts; then
    echo "Adding entry: $entry"
    echo "$entry" | sudo tee -a /etc/hosts > /dev/null
  else
    echo "Entry already exists: $entry"
  fi
done

echo "All entries checked and updated if necessary."

## Prometheus Address and Alert Manager Address
export PROM_ADDR=mon.localhost
echo $PROM_ADDR
export AM_ADDR=alertmanager.localhost
echo $AM_ADDR
export G_ADDR=grafana.localhost
echo $G_ADDR


if ! helm repo list | grep -q 'prometheus-community'; then
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
fi

helm install prometheus \
    prometheus-community/kube-prometheus-stack \
    --set prometheus.ingress.hosts\[0\]="$PROM_ADDR" \
    --set alertmanager.ingress.hosts\[0\]="$AM_ADDR" \
    --set grafana.ingress.hosts\[0\]="$G_ADDR" \
    -f ../monitoring/prometheus-local.yaml \
    --namespace metrics

# helm upgrade prometheus \
#     prometheus-community/kube-prometheus-stack \
#     --set prometheus.ingress.hosts\[0\]="$PROM_ADDR" \
#     --set alertmanager.ingress.hosts\[0\]="$AM_ADDR" \
#     --set grafana.ingress.hosts\[0\]="$G_ADDR" \
#     -f ../monitoring/prometheus-local.yaml \
#     --namespace metrics

## prometheus rules
# kubectl apply -f ../monitoring/prometheus-rule.yaml

# Install the application
kubectl apply -f application-local.yaml
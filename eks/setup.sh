#!/bin/bash

# Set environment variables
if [ -f "../aws-credentials.json" ]; then
    export AWS_ACCESS_KEY_ID=$(jq -r '.AWS_ACCESS_KEY_ID' ../aws-credentials.json)
    export AWS_SECRET_ACCESS_KEY=$(jq -r '.AWS_SECRET_ACCESS_KEY' ../aws-credentials.json)
fi

if [ -z "${AWS_ACCESS_KEY_ID}" ]; then
    echo "Enter AWS_ACCESS_KEY_ID : "
    read AWS_ACCESS_KEY_ID
    export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
fi

if [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
    echo "Enter AWS_SECRET_ACCESS_KEY : "
    read AWS_SECRET_ACCESS_KEY
    export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
fi

export NAME=runay
export AWS_DEFAULT_REGION=ap-south-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)


# Print confirmation
echo "Environment variables have been set:"
echo "NAME=$NAME"
echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
echo "AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION"
echo "AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID"

# Create a new cluster if it doesn't exist

if aws eks describe-cluster --name $NAME >/dev/null 2>&1; then
    echo "$NAME cluster exists"
else
    eksctl create cluster \
    -n $NAME \
    -r $AWS_DEFAULT_REGION \
    --kubeconfig cluster/kubecfg-eks \
    --node-type t2.small \
    --nodes-max 3 \
    --nodes-min 1 \
    --asg-access \
    --managed \
    --spot

    export KUBECONFIG=$PWD/cluster/kubecfg-eks
fi

#update the context
aws eks --region $AWS_DEFAULT_REGION update-kubeconfig --name $NAME

# Setup cluster autoscaler

if ! helm repo list | grep -q 'autoscaler'; then
    helm repo add autoscaler https://kubernetes.github.io/autoscaler
fi

helm install cluster-autoscaler \
    autoscaler/cluster-autoscaler \
    --namespace kube-system \
    --set autoDiscovery.clusterName=$NAME \
    --set awsRegion=$AWS_DEFAULT_REGION \
    --set sslCertPath=/etc/kubernetes/pki/ca.crt \
    --set rbac.create=true

# kubectl -n kube-system get deployment -o name \
#     | grep "cluster-autoscaler" \
#     | xargs -I{} kubectl -n kube-system rollout status {}

# Retrieve the worker node's role name
export IAM_ROLE=$(aws iam list-roles \
    | jq -r ".Roles[] \
    | select(.RoleName \
    | startswith(\"eksctl-$NAME-nodegroup\")) \
    .RoleName")
echo $IAM_ROLE

# Put a role policy for the given IAM role
export EKS_POLICY_PATH=$(realpath scaling/eks-policy.json)
echo $POLICY_PATH

aws iam put-role-policy \
    --role-name $IAM_ROLE \
    --policy-name $NAME-policy \
    --policy-document file:///"$EKS_POLICY_PATH"



# To manage lifcyle of volume: Container Storage Interface (CSI) acts as a plugin layer to surface external storage into Kubernetes.
## Associate the IAM OIDC provider with the cluster
eksctl utils associate-iam-oidc-provider --region $AWS_DEFAULT_REGION --cluster $NAME --approve

## Create IAM Role for EBS CSI Driver
eksctl create iamserviceaccount \
  --region $AWS_DEFAULT_REGION \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster $NAME \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --role-only \
  --role-name AmazonEKS_EBS_CSI_DriverRole

## Install EBS CSI Driver as an EKS add-on
eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster $NAME \
  --service-account-role-arn arn:aws:iam::"$AWS_ACCOUNT_ID":role/AmazonEKS_EBS_CSI_DriverRole \
  --force


# Setup metrics server
if ! helm repo list | grep -q 'metrics-server'; then
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
fi

kubectl create namespace metrics
helm install metrics-server metrics-server/metrics-server -n metrics

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
aws eks --region $AWS_DEFAULT_REGION update-kubeconfig --name $NAME

LB_HOST=$(kubectl -n ingress-nginx \
    get svc ingress-nginx-controller \
    -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")

export LB_IP="$(dig +short $LB_HOST \
    | tail -n 1)"

echo "LB_IP=$LB_IP"
export LB_IP=$LB_IP
export LB_URL="http://$LB_IP"



# Setup Prometheus

## Prometheus Address and Alert Manager Address
export PROM_ADDR=mon.$LB_IP.nip.io
echo $PROM_ADDR
export AM_ADDR=alertmanager.$LB_IP.nip.io
echo $AM_ADDR
export G_ADDR=grafana.$LB_IP.nip.io
echo $G_ADDR


# Create custom storage class
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: custom-gp3
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF

if ! helm repo list | grep -q 'prometheus-community'; then
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
fi

helm install prometheus \
    prometheus-community/kube-prometheus-stack \
    --set prometheus.ingress.hosts\[0\]="$PROM_ADDR" \
    --set alertmanager.ingress.hosts\[0\]="$AM_ADDR" \
    --set grafana.ingress.hosts\[0\]="$G_ADDR" \
    -f ../monitoring/prometheus.yaml \
    --namespace metrics

# helm upgrade prometheus \
#     prometheus-community/kube-prometheus-stack \
#     --set prometheus.ingress.hosts\[0\]="$PROM_ADDR" \
#     --set alertmanager.ingress.hosts\[0\]="$AM_ADDR" \
#     --set grafana.ingress.hosts\[0\]="$G_ADDR" \
#     -f ../monitoring/prometheus.yaml \
#     --namespace metrics

## prometheus rules
# kubectl apply -f ../monitoring/prometheus-rule.yaml

# Install the application
kubectl apply -f application.yaml
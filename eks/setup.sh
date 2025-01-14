#!/bin/bash

# Run pre-setup.sh before this script

# Create a new cluster

eksctl create cluster \
-n $NAME \
-r $AWS_DEFAULT_REGION \
--kubeconfig cluster/kubecfg-eks \
--node-type t2.small \
--nodes-max 3 \
--nodes-min 1 \
--asg-access \
--managed


export KUBECONFIG=$PWD/cluster/kubecfg-eks

#update the context
aws eks --region $AWS_DEFAULT_REGION update-kubeconfig --name $NAME


# Install Ingress
###################
# Install Ingress #
###################

kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/1cd17cd12c98563407ad03812aebac46ca4442f2/deploy/mandatory.yaml

kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/1cd17cd12c98563407ad03812aebac46ca4442f2/deploy/provider/aws/service-l4.yaml

kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/1cd17cd12c98563407ad03812aebac46ca4442f2/deploy/provider/aws/patch-configmap-l4.yaml



# Setup metrics server
kubectl create namespace metrics

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/

helm upgrade --install metrics-server metrics-server/metrics-server -n metrics

kubectl -n metrics \
rollout status \
deployment metrics-server


# Retrieve the worker node's role name
IAM_ROLE=$(aws iam list-roles \
    | jq -r ".Roles[] \
    | select(.RoleName \
    | startswith(\"eksctl-$NAME-nodegroup\")) \
    .RoleName")
echo $IAM_ROLE


# Put a role policy for the given IAM role
aws iam put-role-policy \
    --role-name $IAM_ROLE \
    --policy-name $NAME-AutoScaling \
    --policy-document file://scaling/eks-autoscaling-policy.json



# Setup cluster autoscaler

helm repo add autoscaler https://kubernetes.github.io/autoscaler

helm install cluster-autoscaler \
    autoscaler/cluster-autoscaler \
    --namespace kube-system \
    --set autoDiscovery.clusterName=$NAME \
    --set awsRegion=$AWS_DEFAULT_REGION \
    --set sslCertPath=/etc/kubernetes/pki/ca.crt \
    --set rbac.create=true

kubectl -n kube-system get deployment -o name \
    | grep "cluster-autoscaler" \
    | xargs -I{} kubectl -n kube-system rollout status {}



# LB Ip
##################
# Get Cluster IP #
##################

LB_HOST=$(kubectl -n ingress-nginx \
    get svc ingress-nginx \
    -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")

export LB_IP="$(dig +short $LB_HOST \
    | tail -n 1)"

echo $LB_IP
export LB_IP=$LB_IP
export LB_URL="http://$LB_IP"
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

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


# Create custom policy that grants sts full access by creating custom policy

# Create role ('AssumeAdmin') that can assume the role of the AdminstratorAccess.

# Assume the role of the AdminstratorAccess for 1 hour
# aws sts assume-role --role-arn arn:aws:iam::225989374887:role/AssumeAdmin --external-id 'kubernetes-admin' --role-session-name 'kubernetes-admin'
export TEMP_ROLE_JSON=$(aws sts assume-role \
  --role-arn arn:aws:iam::225989374887:role/AssumeAdmin \
  --external-id 'kubernetes-admin' \
  --role-session-name 'kubernetes-admin')

export AWS_ACCESS_KEY_ID=$(echo "$TEMP_ROLE_JSON" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$TEMP_ROLE_JSON" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$TEMP_ROLE_JSON" | jq -r '.Credentials.SessionToken')


# Describe EC2 instances
aws ec2 describe-instances


cd terraform

# create necesary .tf files then
# Initialize terraform
terraform init

# apply terraform
terraform apply -auto-approve


# Create kOps cluster
kops create cluster \
    --cloud=aws \
    --name=kops-cluster-ufdoyoujlsjigvhb.k8s.local \
    --zones=ap-south-1a \
    --state='s3://ufdoyoujlsjigvhb-kops-state-store' \
    --discovery-store='s3://ufdoyoujlsjigvhb-kops-state-store/discovery' \
    --dry-run -o yaml | tee ./cluster.yaml

# tfstate backup. can be stored in remote repo
cp ./terraform.tfstate /tmp/terraform.tfstate


kops create \
    --filename ./cluster.yaml \
    --state='s3://ufdoyoujlsjigvhb-kops-state-store'

kops update cluster --name kops-cluster-ufdoyoujlsjigvhb.k8s.local --yes \
    --state='s3://ufdoyoujlsjigvhb-kops-state-store' \
    --admin

kops validate cluster --state='s3://ufdoyoujlsjigvhb-kops-state-store' --wait 10m 



# Testing cluster
kubectl run \
    --rm --stdin \
    --image=hello-world \
    --restart=Never \
    --request-timeout=10s \
    test-pod


# Delete the kops cluster
kops delete cluster --name kops-cluster-ufdoyoujlsjigvhb.k8s.local --yes \
    --state='s3://ufdoyoujlsjigvhb-kops-state-store' \
    --yes

# Destroy the terraform resources
terraform destroy
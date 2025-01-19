
# Delete the nodegroup
IAM_ROLE=$(aws iam list-roles \
| jq -r ".Roles[] \
| select(.RoleName \
| startswith(\"eksctl-$NAME-nodegroup\")) \
.RoleName")

echo $IAM_ROLE

aws iam delete-role-policy \
--role-name $IAM_ROLE \
--policy-name $NAME-policy


# Delete the EKS cluster

eksctl delete cluster -n $NAME


# Delete the security group
SG_NAME=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=k8s-elb-$LB_NAME \
    | jq -r ".SecurityGroups[0].GroupId")

echo $SG_NAME

if [ -n "$SG_NAME" ]; then
  aws ec2 delete-security-group --group-id $SG_NAME
else
  echo "SG_NAME is null or empty. Exiting."
fi

IAM_ROLE=$(aws iam list-roles \
| jq -r ".Roles[] \
| select(.RoleName \
| startswith(\"eksctl-$NAME-nodegroup\")) \
.RoleName")

echo $IAM_ROLE

aws iam delete-role-policy \
--role-name $IAM_ROLE \
--policy-name $NAME-AutoScaling

eksctl delete cluster -n $NAME
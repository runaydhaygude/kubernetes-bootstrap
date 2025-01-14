### Run following commands when using these .sh files for the first time to give necessary access to run the scripts.
cd eks

chmod +x pre-setup.sh

chmod +x setup.sh

chmod +x terminate.sh



### Few commands that are not part of the scripts

helm uninstall <release-name> -n kube-system
helm uninstall cluster-autoscaler-aws-cluster-autoscaler -n kube-system


kubectl delete -f <file-name>
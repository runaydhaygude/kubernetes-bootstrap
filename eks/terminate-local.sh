
## prometheus rules
# kubectl delete -f ../monitoring/prometheus-rule.yaml

# Install the application
kubectl delete -f application-local.yaml

kubectl delete -f persistent-volume-local.yaml

# kubectl delete sc custom-gp3

# kubectl delete -f https://openebs.github.io/charts/openebs-operator.yaml

# helm uninstall metrics-server -n metrics

helm uninstall prometheus -n metrics

helm uninstall ingress-nginx -n ingress-nginx

kubectl delete ns ingress-nginx

kubectl delete ns metrics

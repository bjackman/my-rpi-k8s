export KUBECONFIG=$PWD/k3s.yaml

kubectl --kubeconfig k3s.yaml apply -f prometheus/deployment.yaml

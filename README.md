Commands
===

```
export KUBECONFIG=$PWD/k3s.yaml

kubectl --kubeconfig k3s.yaml apply -f prometheus/deployment.yaml  # or whichever file
```

TODOs
===

Stuff outside this repo:

- Find a way to monitor the cluster host OS (resource availability, host upgrade
  status)?
- Install system-upgrade-controller to auto-upgrade k3s

Stuff inside this repo:

- Find out how to continuously deliver prometheus
- Switch to Ingress (?) to get rid of NodePort hackery
- Persist & share prometheus data

Commands
===

- Set up kubectl: `export KUBECONFIG=$PWD/k3s.yaml`

- You need to have a DNS server running in your cluster for serviec discovery purposes. It maps the name of each services to its ClusterIP. So...

  ```
  ./coredns-deployment/kubernetes/deploy.sh | kubectl apply -f -
  ```

  🤠 🤠 YEE HAW we're CLOUD NATIVE baybee! 🤠 🤠

- Now something like `helm upgrade --install graphs .`

TODOs
===

Stuff outside this repo:

- Find a way to monitor the cluster host OS (host upgrade status)?
- Install system-upgrade-controller to auto-upgrade k3s

Stuff inside this repo:

- Put these k8s resources in a damn namespace you silly idiot
- Find out how to continuously deliver prometheus
- Persist & share prometheus data (Cortex)
- node_exporter
- Grafana (with peristent dashbards)

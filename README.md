Commands
===

- Set up kubectl: `export KUBECONFIG=$PWD/k3s.yaml`

- (This might not actually be true - k3s and microk8s seem to include this by default after all): You need to have a DNS server running in your cluster for serviec discovery purposes. It maps the name of each services to its ClusterIP. So...

  ```
  ./coredns-deployment/kubernetes/deploy.sh | kubectl apply -f -
  ```

  🤠 🤠 YEE HAW we're CLOUD NATIVE baybee! 🤠 🤠

- Install [kubecfg](https://github.com/bitnami/kubecfg/)

- `kubecfg update everything.jsonnet`

TODOs
===

Current status: node-exporter is running and I think Prometheus is discovering
and scraping it. Same for kubelet metrics. However for some reason the Grafana
dashboards for that don't work.

Stuff outside this repo:

- Find a way to monitor the cluster host OS (host upgrade status)?
- Install system-upgrade-controller to auto-upgrade k3s
- Go multi-node

Stuff inside this repo:

- Put these k8s resources in a damn namespace you silly idiot
- Find out how to continuously deliver stuff
- Persist & share prometheus data (Cortex)
- node_exporter
- https://github.com/pdreker/fritzbox_exporter
- Parameterise the helm chart:
  - "rpi"
  - port numbers?


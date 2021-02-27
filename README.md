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

Tring to add another dashboard, but it's big complex json with templates in it, and so is a Helm chart. Helm is annoying generally and doesn't seem to be deliverying any value. SO... let's convert everything to JSonnet:

# Dump manifests:
~/src/kubecfg/kubecfg  show everything.jsonnet

# Compare with server:
~/src/kubecfg/kubecfg  diff everything.jsonnet

I got as far as converting grafana_deployment.yaml. Next step is to convert the config_map.


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


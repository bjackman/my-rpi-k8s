Commands
===

- Set up kubectl: `export KUBECONFIG=$PWD/k3s.yaml`

- You need to have a DNS server running in your cluster for serviec discovery purposes. It maps the name of each services to its ClusterIP. So...

  ```
  ./coredns-deployment/kubernetes/deploy.sh | kubectl apply -f -
  ```

  🤠 🤠 YEE HAW we're CLOUD NATIVE baybee! 🤠 🤠

- Now you have to `kubectl apply` all the resources described by the YAML files in here. Not sure if it matters which order you do this in. You'll figure it out.

TODOs
===

Stuff outside this repo:

- Find a way to monitor the cluster host OS (resource availability, host upgrade
  status)?
- Install system-upgrade-controller to auto-upgrade k3s

Stuff inside this repo:

- Put these k8s resources in a damn namespace you silly idiot
- Find out how to continuously deliver prometheus
- Switch to Ingress (?) to get rid of NodePort hackery
- Persist & share prometheus data

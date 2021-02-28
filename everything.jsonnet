// local kube = import "https://github.com/bitnami-labs/kube-libsonnet/raw/0e78b4332a893b7c1d03eefc84f9a2ef7d28b8ad/kube.libsonnet";
local kube = import "kube.libsonnet";

local dashboard_airdata = importstr "dashboard_airdata.json";
local dashboard_scraper = importstr "dashboard_scraper.json";
local dashboard_node = importstr "dashboard_node.json";
local dashboard_kubelet = importstr "dashboard_kubelet.json";

{
  ingress: kube.Ingress("graphs") {
    spec: {
      rules: [
        {
          http: {
            paths: [
              {
                path: "/prom",
                pathType: "Prefix",
                backend: {
                  service: $.prometheus.svc.name_port,
                },
              },
              {
                path: "/grafana",
                pathType: "Prefix",
                backend: {
                  service: $.grafana.svc.name_port,
                },
              },
            ],
          },
        },
      ],
    },
  },

  awair: {
    local name = "awair",
    local awair = self,

    svc: kube.Service(name) {
      target_pod: awair.deploy.spec.template,
    },

    deploy: kube.Deployment(name) {
      spec+: {
        template+: {
          spec+: {
            containers_: {
              [name]: kube.Container(name) {
                image: "bjackman/awair-local-prometheus:latest",
                ports: [{ name: name, containerPort: 8080 }],
                command: ["awair-local-prometheus", "--awair-address=http://awair-elem-143b7b/"],
              },
            },
          },
        },
      },
    },
  },

  # Copied this stuff from
  # https://rtfm.co.ua/en/kubernetes-monitoring-with-prometheus-exporters-a-service-discovery-and-its-roles/#Prometheus_ClusterRole,_ServiceAccount,_and_ClusterRoleBinding
  role: kube.ClusterRole("readonly") {
    rules: [
      {
        apiGroups: [""],
        resources: ["services", "endpoints", "pods", "nodes", "nodes/proxy", "nodes/metrics"],
        verbs: ["get", "list", "watch"],
      },
      {
        nonResourceURLs: ["/metrics"],
        verbs: ["get"],
      },
    ],
  },
  account: kube.ServiceAccount("readonly"),
  binding: kube.ClusterRoleBinding("readonly") {
    subjects_: [$.account],
    roleRef_: $.role,
  },

  nodeExporter: {
    local name = "node-exporter",
    local nodeExporter = self,

    svc: kube.Service(name) {
      target_pod: nodeExporter.daemonSet.spec.template,
    },

    daemonSet: kube.DaemonSet(name) {
      spec+: {
        template+: {
          spec+: {
            hostPID: true,
            hostIPC: true,
            hostNetwork: true,
            containers_: {
              [name]: kube.Container(name) {
                image: "prom/node-exporter",
                args: [
                  "--path.procfs", "/host/proc",
                  "--path.sysfs", "/host/sys",
                  "--collector.filesystem.ignored-mount-points", '"^/(sys|proc|dev|host|etc)($|/)"',
                ],
                ports: [{ name: name, containerPort: 9100 }],
                securityContext: { privileged: true },
                volumeMounts_: {
                  "dev": {mountPath: "/host/dev" },
                  "proc": {mountPath: "/host/proc" },
                  "sys": {mountPath: "/host/sys" },
                  "rootfs": {mountPath: "/rootfs" },
                },
              },
            },
            volumes_: {
              "dev": {hostPath: {path: "/host/dev" }},
              "proc": {hostPath: {path: "/host/proc" }},
              "sys": {hostPath: {path: "/host/sys" }},
              "rootfs": {hostPath: {path: "/" }},
            },
          },
        },
      },
    },
  },

  prometheus: {
    local name = "prometheus",
    local prometheus = self,

    svc: kube.Service(name) {
      target_pod: prometheus.deploy.spec.template,
    },

    deploy: kube.Deployment(name) {
      spec+: {
        template+: {
          spec+: {
            serviceAccountName: $.account.metadata.name,
            containers_: {
              [name]: kube.Container(name) {
                name: name,
                image: "prom/prometheus:v2.24.0", # UPDATE ME!
                command: [
                  "/bin/prometheus",
                  "--config.file=/etc/prometheus/prometheus.yml",
                  "--storage.tsdb.path=/prometheus",
                  "--web.console.libraries=/usr/share/prometheus/console_libraries",
                  "--web.console.templates=/usr/share/prometheus/consoles",
                  "--web.external-url=http://rpi/prom",
                  "--web.enable-lifecycle",
                ],
                ports: [{ name: name, containerPort: 9090 }],
                volumeMounts_: {
                  config: {
                    mountPath: "/etc/prometheus",
                    readOnly: true,
                  }
                }
              },
            },
            volumes_: {
              config: {
                configMap: {
                  name: name,
                  items: [{
                    key: "config",
                    path: "prometheus.yml",
                  }],
                },
              },
            },
          },
        },
      },
    },

    config: kube.ConfigMap(name) {
      data: {
        config: |||
          # my global config
          global:
            scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
            evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
            # scrape_timeout is set to the global default (10s).

          # Alertmanager configuration
          alerting:
            alertmanagers:
            - static_configs:
                - targets:
                # - alertmanager:9093

          # Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
          rule_files:
            # - "first_rules.yml"
            # - "second_rules.yml"

          # A scrape configuration containing exactly one endpoint to scrape:
          # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
          scrape_configs:
            # Here it's Prometheus itself.
            - job_name: 'prometheus'
              static_configs:
              - targets: ['localhost:9090']
            # And now we scrape from the awair-local-prometheus service
            - job_name: 'awair'
              static_configs:
              - targets: ['awair:8080']
            - job_name: 'air-data'
              metrics_path: '/air-data'
              static_configs:
              - targets: ['awair:8080']
            - job_name: 'nodes'
              static_configs:
              - targets: ['rpi:9100']
            # TODO This doesn't work, we get 401 Unauthorized. Might be missing
            # cluster/kubelet config for RBAC. Not sure, don't think I care
            # enough.
            - job_name: 'kubelets'
              scheme: https
              tls_config:
                ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
              bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
              kubernetes_sd_configs:
              - role: node
            - job_name: 'node-exporter'
              kubernetes_sd_configs:
                - role: endpoints
              relabel_configs:
              - source_labels: [__meta_kubernetes_endpoints_name]
                regex: 'node-exporter'
                action: keep
        |||,
      },
    },
  },

  grafana: {
    local name = "grafana",
    local grafana = self,

    svc: kube.Service(name) {
      target_pod: grafana.deploy.spec.template,
    },

    deploy: kube.Deployment(name) {
      spec+: {
        template+: {
          spec+: {
            containers_: {
              [name]: kube.Container(name) {
                image: "grafana/grafana:7.3.7",
                ports: [{ name: name, containerPort: 3000 }],
                # Instead of a ConfigMap, let's just go to town with env vars:
                  # https://grafana.com/docs/grafana/latest/administration/configuration/#configure-with-environment-variables
                env_: {
                  # https://grafana.com/tutorials/run-grafana-behind-a-proxy
                  "GF_SERVER_DOMAIN": "rpi",
                  "GF_SERVER_ROOT_URL": "%(protocol)s://%(domain)s:%(http_port)s/grafana/",
                  "GF_SERVER_SERVE_FROM_SUB_PATH": "true",
                  # https://grafana.com/docs/grafana/latest/auth/overview/#anonymous-authentication
                  "GF_AUTH_ANONYMOUS_ENABLED": "true",
                  "GF_AUTH_ANONYMOUS_ORG_NAME": "Main Org.",
                  "GF_AUTH_ANONYMOUS_ORG_ROLE": "Viewer",
                  # There is no auth lol
                  "GF_AUTH_BASIC_ENABLED": "false",
                },
                volumeMounts_: {
                  provisioning: {
                    mountPath: "/etc/grafana/provisioning",
                    readOnly: true,
                  },
                  dashboards: {
                    mountPath: "/var/lib/grafana/dashboards",
                    readOnly: true,
                  },
                },
              },
            },
            volumes_: {
              dashboards: {
                configMap: {
                  name: grafana.dashboardsConfig.metadata.name,
                },
              },
              provisioning: {
                configMap: {
                  name: name,
                  items: [
                    {
                      key: "data_source",
                      path: "datasources/prometheus.yaml",
                    },
                    {
                      key: "dashboards",
                      path: "dashboards/dashboards.yaml",
                    },
                  ],
                },
              },
            },
          },
        },
      },
    },

    dashboardsConfig: kube.ConfigMap(name + "-dashboards") {
      data: {
        "airdata.json": dashboard_airdata,
        "airscraper.json": dashboard_scraper,
        "dashboard_node.json": dashboard_node,
        "dashboard_kubelet.json": dashboard_kubelet,
      },
    },

    provisioningConfig: kube.ConfigMap(name + "-provisioning") {
      data: {
        # https://grafana.com/docs/grafana/latest/administration/provisioning/#example-data-source-config-file
        data_source: |||
          apiVersion: 1
          datasources:
          - name: Prometheus
            type: prometheus
            # Have Grafana backend fetch this data source, instead of user's browser
            access: proxy
            url: "http://prometheus:9090/prom"
            version: 1
            editable: false
        |||,
        # https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards
        dashboards:  |||
          apiVersion: 1
          providers:
            - name: 'Dashboards from Git'
              type: file
              allowUpdates: false
              options:
                path: /var/lib/grafana/dashboards
                foldersFromFileStructor: true
        |||,
      },
    }
  },
}

// local kube = import "https://github.com/bitnami-labs/kube-libsonnet/raw/0e78b4332a893b7c1d03eefc84f9a2ef7d28b8ad/kube.libsonnet";
local kube = import "kube.libsonnet";

local dashboard_airdata = importstr "dashboard_airdata.json";
local dashboard_scraper = importstr "dashboard_scraper.json";

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
                  name: name,
                  items: [
                    {
                      key: "dashboard_airdata",
                      path: "airdata.json",
                    },
                    {
                      key: "dashboard_airscraper",
                      path: "airscraper.json",
                    },
                    // {
                    //   key: "dashboard_nodes",
                    //   path: "nodes.json",
                    // },
                  ],
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

    // # TODO make this more concise.

    config: kube.ConfigMap(name) {
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
        dashboard_airdata: dashboard_airdata,
        dashboard_scraper: dashboard_scraper,
        // dashboard_node: dashboard_node,
      },
    },
  },
}

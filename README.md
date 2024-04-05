# Observability-with-Grafana-Loki
## prerequisite 

# Setting up Kubernetes using Minikube

Setting up Kubernetes using Minikube is a straightforward process. Minikube is a tool that allows you to run a single-node Kubernetes cluster locally on your machine. Here's a step-by-step guide to get you started:

**Install Minikube**:
   - First, you need to install Minikube. You can download the latest version from the [official GitHub repository](https://github.com/kubernetes/minikube/releases).
   - Follow the installation instructions for your operating system. [guide](https://minikube.sigs.k8s.io/docs/start/)

# Setting up Terraform

To set up Terraform, you'll need to follow a series of steps to install the Terraform CLI and initialize your Terraform project. Here's a [guide](https://developer.hashicorp.com/terraform/install) to help you get started

## Steps

### file tree
      └── Observability-with-Grafana-Loki
          ├── README.md
          ├── manifest_file
          │   └── deployment.yaml
          └── terraform_file
              ├── main.tf
              ├── terraform.tfstate
              ├── terraform.tfstate.backup
              └── values
                  └── values.yaml
 

#### add the Grafana repo
      helm repo add grafana https://grafana.github.io/helm-charts
      
#### extract the helm values of grafana/loki-stack and direct it to a yaml file
      helm show values grafana/loki-stack > values.yaml

#### initialize the working directory
      terraform init
#### provision the infrastructure 
#### **main.tf** file

      provider "kubernetes" {
          config_path = "~/.kube/config"
          config_context = "minikube"
      }
      provider "helm" {
          kubernetes {
            config_path = "~/.kube/config"
            config_context = "minikube"
          }
      }
      
      # creating a namespace for Observability and app
      resource "kubernetes_namespace" "Observability-namespace" {
        metadata {
          name = "observability"
        }
      }
      
      resource "kubernetes_namespace" "app-namespace" {
        metadata {
          name = "app"
        }
      }
      
      
      # creating a nginx deployment
      resource "helm_release" "nginx" {
        name       = "nginx"
        repository = "https://charts.bitnami.com/bitnami"
        chart      = "nginx"
        version = "15.14.2"
        namespace = "app"
        set {
          name  = "nginx"
          value = "ClusterIP"
        }
        
      }
      
      resource "kubernetes_ingress_v1" "nginx-ingress" {
        metadata {
          name = "app-ingress"
          namespace = "app"
        }
        spec {
          rule {
            host = "malik0x.lol"
            http {
              path {
                  path_type = "Prefix"
                  path = "/"
                  backend {
                      service {
                          name = "nginx"
                          port {
                              number = 80
                          }
                      }
                  }
              }
            }
          }
        }
      }
      
      
      # installation of Loki-Grafana
      resource "helm_release" "grafana" {
        name       = "loki"
        repository = "https://grafana.github.io/helm-charts"
        chart      = "loki-stack"
        namespace = "observability"
        
        values = [file("${path.module}/values/values.yaml")]
      }


#### grafana **values.yaml** file 
      test_pod:
        enabled: true
        image: bats/bats:1.8.2
        pullPolicy: IfNotPresent
      
      loki:
        enabled: true
        isDefault: true
        url: http://{{(include "loki.serviceName" .)}}:{{ .Values.loki.service.port }}
        readinessProbe:
          httpGet:
            path: /ready
            port: http-metrics
          initialDelaySeconds: 45
        livenessProbe:
          httpGet:
            path: /ready
            port: http-metrics
          initialDelaySeconds: 45
        datasource:
          jsonData: "{}"
          uid: ""
      
      
      promtail:
        enabled: true
        config:
          logLevel: info
          serverPort: 3101
          clients:
            - url: http://{{ .Release.Name }}:3100/loki/api/v1/push
      
      fluent-bit:
        enabled: false
      
      grafana:
        enabled: true
        sidecar:
          datasources:
            label: ""
            labelValue: ""
            enabled: true
            maxLines: 1000
        image:
          tag: latest
      
      prometheus:
        enabled: false
        isDefault: false
        url: http://{{ include "prometheus.fullname" .}}:{{ .Values.prometheus.server.service.servicePort }}{{ .Values.prometheus.server.prefixURL }}
        datasource:
          jsonData: "{}"
      
      filebeat:
        enabled: false
        filebeatConfig:
          filebeat.yml: |
            # logging.level: debug
            filebeat.inputs:
            - type: container
              paths:
                - /var/log/containers/*.log
              processors:
              - add_kubernetes_metadata:
                  host: ${NODE_NAME}
                  matchers:
                  - logs_path:
                      logs_path: "/var/log/containers/"
            output.logstash:
              hosts: ["logstash-loki:5044"]
      
      logstash:
        enabled: false
        image: grafana/logstash-output-loki
        imageTag: 1.0.1
        filters:
          main: |-
            filter {
              if [kubernetes] {
                mutate {
                  add_field => {
                    "container_name" => "%{[kubernetes][container][name]}"
                    "namespace" => "%{[kubernetes][namespace]}"
                    "pod" => "%{[kubernetes][pod][name]}"
                  }
                  replace => { "host" => "%{[kubernetes][node][name]}"}
                }
              }
              mutate {
                remove_field => ["tags"]
              }
            }
        outputs:
          main: |-
            output {
              loki {
                url => "http://loki:3100/loki/api/v1/push"
                #username => "test"
                #password => "test"
              }
              # stdout { codec => rubydebug }
            }
      
      # proxy is currently only used by loki test pod
      # Note: If http_proxy/https_proxy are set, then no_proxy should include the
      # loki service name, so that tests are able to communicate with the loki
      # service.
      proxy:
        http_proxy: ""
        https_proxy: ""
        no_proxy: ""
      
#### the terraform file will provision the following
1. creating namespace (app and observability)
2. creating nginx deployment with helm chart in app namespace
3. expose the nginx deployment using ingress in app namespace
4. creating Grafana-loki with helm in observability namespace

#### validate the code
      terraform validate 
      terraform plan
      
#### build the infrasture
      terraform apply --auto-approve

#### check all deployment in app namespace
      kubectl get all -n app
#### output
      NAME                         READY   STATUS    RESTARTS        AGE
      pod/nginx-665fdd4b55-4xpd5   1/1     Running   1 (4h47m ago)   40h
      
      NAME            TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
      service/nginx   LoadBalancer   10.103.39.213   127.0.0.1     80:32666/TCP   40h
      
      NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
      deployment.apps/nginx   1/1     1            1           40h
      
      NAME                               DESIRED   CURRENT   READY   AGE
      replicaset.apps/nginx-665fdd4b55   1         1         1       40h

#### check all deployment in observability namespace
      kubectl get all -n observability 
#### output
      NAME                                READY   STATUS    RESTARTS   AGE
      pod/loki-0                          1/1     Running   0          3h49m
      pod/loki-grafana-585c7dd66d-ldv5l   2/2     Running   0          3h49m
      pod/loki-promtail-lns5r             1/1     Running   0          3h49m
      
      NAME                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
      service/loki              ClusterIP   10.100.213.126   <none>        3100/TCP   3h49m
      service/loki-grafana      ClusterIP   10.104.194.145   <none>        80/TCP     3h49m
      service/loki-headless     ClusterIP   None             <none>        3100/TCP   3h49m
      service/loki-memberlist   ClusterIP   None             <none>        7946/TCP   3h49m
      
      NAME                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
      daemonset.apps/loki-promtail   1         1         1       1            1           <none>          3h49m
      
      NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
      deployment.apps/loki-grafana   1/1     1            1           3h49m
      
      NAME                                      DESIRED   CURRENT   READY   AGE
      replicaset.apps/loki-grafana-585c7dd66d   1         1         1       3h49m
      
      NAME                    READY   AGE
      statefulset.apps/loki   1/1     3h49m

#### check the ingress
      kubectl get all -n app
#### output
      NAME          CLASS   HOSTS         ADDRESS        PORTS   AGE
      app-ingress   nginx   malik0x.lol   192.168.49.2   80      40h

#### add the domain to `/etc/hosts` file

#### ping the domain name
      curl malik0x.lol
#### output
      <!DOCTYPE html>
      <html>
      <head>
      <title>Welcome to nginx!</title>
      <style>
      ................


#### Note for Docker Desktop Users:
To get ingress to work you’ll need to open a new terminal window and run minikube tunnel and in the following step use 127.0.0.1 in place of <ip_from_above>.

#### nginx interface 
<img src="images/Screenshot 2023-10-17 134353.png" alt="Alt text">

#### decode the grafana secret and login
      ~$ kubectl get secret -n observability
      NAME                         TYPE                 DATA   AGE
      loki                         Opaque               1      4h
      loki-grafana                 Opaque               3      4h
      loki-promtail                Opaque               1      4h
      sh.helm.release.v1.loki.v1   helm.sh/release.v1   1      4h
      
      ~$ kubectl describe secret loki-grafana -n observability
      
      Name:         loki-grafana
      Namespace:    observability
      Labels:       app.kubernetes.io/instance=loki
                    app.kubernetes.io/managed-by=Helm
                    app.kubernetes.io/name=grafana
                    app.kubernetes.io/version=latest
                    helm.sh/chart=grafana-6.43.5
      Annotations:  meta.helm.sh/release-name: loki
                    meta.helm.sh/release-namespace: observability
      
      Type:  Opaque
      
      Data
      ====
      ldap-toml:       0 bytes
      admin-password:  40 bytes
      admin-user:      5 bytes
      
      
      ~$ kubectl get secret loki-grafana -n observability -o jsonpath="{.data.admin-password}" | base64 --decode
      q1emLzdrV2mu6YLs7If5EwZvXGkdG4yuuIpTeiYa

#### grafana interface 
<img src="images/Screenshot 2023-10-17 134353.png" alt="Alt text">

#### to destroy the whole infrastructure
      terraform destroy --auto-approve

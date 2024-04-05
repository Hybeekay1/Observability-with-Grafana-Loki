

# Configure Kubernetes provider and connect to the Kubernetes API server
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
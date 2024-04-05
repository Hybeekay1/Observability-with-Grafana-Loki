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

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.22.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.2.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.1.1"
    }
  }
}

provider "digitalocean" {
}

provider "random" {
}

provider "helm" {
  alias = "mgmt"
  kubernetes {
    host                   = digitalocean_kubernetes_cluster.mgmt.endpoint
    token                  = digitalocean_kubernetes_cluster.mgmt.kube_config[0].token
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.mgmt.kube_config[0].cluster_ca_certificate)
  }
}

provider "local" {}

provider "null" {}

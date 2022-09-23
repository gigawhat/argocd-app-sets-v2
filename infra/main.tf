locals {
  numClusters = 1
  clusterNames = [
    for i in random_pet.clusterNames : i.id
  ]
  argocd_values = {
    server = {
      service = {
        type = "NodePort"
      }
    }
    configs = {
      secret = {
        argocdServerAdminPassword = "$2a$12$gzNKmK5WOyTEzvl0tPbQk.X37aN38cOYCZGnc1J7i0CpE.amQvtDC"
      }
      clusterCredentials = [for i in digitalocean_kubernetes_cluster.clusters : {
        name   = i.name
        server = i.endpoint
        config = {
          bearerToken = i.kube_config[0].token
          tlsClientConfig = {
            insecure = false
            caData   = i.kube_config[0].cluster_ca_certificate
          }
        }
      }]
      repositories = {
        argocd-app-sets-v2 = {
          name = "argocd-app-sets-v2"
          url  = "https://github.com/gigawhat/argocd-app-sets-v2.git"
        }
      }
    }
  }
  argocd_apps_values = {
    applications = [
      {
        name      = "application-sets"
        namespace = "argo-cd"
        project   = "default"
        source = {
          repoURL        = "https://github.com/gigawhat/argocd-app-sets-v2.git"
          targetRevision = "HEAD"
          path           = "app-sets"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argo-cd"
        }
        syncPolicy = {
          automated = {}
        }
      }
    ]
  }
}

# Create mgmt cluster and deploy argocd
resource "digitalocean_kubernetes_cluster" "mgmt" {
  name    = "mgmt"
  region  = "sfo3"
  version = "1.24.4-do.0"
  node_pool {
    name       = "default"
    size       = "s-1vcpu-2gb"
    node_count = 1
  }
}

data "digitalocean_droplet" "mgmt" {
  id = digitalocean_kubernetes_cluster.mgmt.node_pool[0].nodes[0].droplet_id
}

resource "helm_release" "argocd" {
  provider         = helm.mgmt
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.5.4"
  namespace        = "argo-cd"
  create_namespace = true
  values           = [yamlencode(local.argocd_values)]
  depends_on = [
    digitalocean_kubernetes_cluster.mgmt,
  ]
}

resource "helm_release" "argocd-apps" {
  provider         = helm.mgmt
  name             = "argocd-apps"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  version          = "0.0.1"
  namespace        = helm_release.argocd.namespace
  create_namespace = false
  values           = [yamlencode(local.argocd_apps_values)]
  depends_on = [
    digitalocean_kubernetes_cluster.mgmt,
  ]
}

resource "random_pet" "clusterNames" {
  count = local.numClusters
}

resource "digitalocean_kubernetes_cluster" "clusters" {
  for_each = toset(local.clusterNames)
  name     = each.key
  region   = "sfo3"
  version  = "1.24.4-do.0"
  node_pool {
    name       = "default"
    size       = "s-1vcpu-2gb"
    node_count = 1
  }
}

output "argocd_url" {
  value = "https://${data.digitalocean_droplet.mgmt.ipv4_address}:30443"
}

output "foo" {
  value = local.clusterNames
}

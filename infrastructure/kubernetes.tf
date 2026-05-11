module "kubernetes" {
  source             = "git::https://github.com/igorsilva-dev/tf-modules.git//civo/kubernetes?ref=v0.1.0"
  cluster_name       = "k8s-labs"
  write_kubeconfig   = true
  network_id         = module.network.network_id
  firewall_id        = module.network.firewall_id
  kubernetes_version = "1.34.2-k3s1"


  pools = [
    {
      label      = "worker-pool-1"
      size       = "g4s.kube.xsmall"
      node_count = 1
    }
  ]
}

module "argocd" {
  source = "git::https://github.com/igorsilva-dev/tf-modules.git//helm?ref=v2026.05.11.02"

  chart_name       = "argocd"
  chart            = "argo-cd"
  chart_repository = "https://argoproj.github.io/argo-helm"
  chart_version    = "7.7.10"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 900
  wait             = false

  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = true
        }
      }
      controller = {
        replicas = 1
        metrics  = { enabled = true }
      }
      "redis-ha"     = { enabled = false }
      server         = { service = { type = "ClusterIP" } }
      dex            = { enabled = false }
      notifications  = { enabled = false }
      applicationSet = { enabled = false }
    })
  ]
}

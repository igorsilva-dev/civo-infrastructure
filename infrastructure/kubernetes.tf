module "kubernetes" {
  source             = "git::https://github.com/igorsilva-dev/tf-modules.git//civo/kubernetes?ref=v2025.11.18.03"
  cluster_name       = "k8s-labs"
  write_kubeconfig   = true
  network_id         = module.network.network_id
  firewall_id        = module.network.firewall_id
  kubernetes_version = "1.31.6-k3s1"

  pools = [
    {
      label      = "worker-pool-1"
      size       = "g4s.kube.xsmall"
      node_count = 1
    }
  ]
}

# module "argocd" {
#   source = "git::https://github.com/igorsilva-dev/tf-modules.git//helm?ref=v2025.11.18.03"

#   # Ensure this runs after the Kubernetes cluster is created
#   depends_on = [module.kubernetes]

#   # ArgoCD Helm chart configuration
#   chart            = "argo-cd"
#   repository       = "https://argoproj.github.io/argo-helm"
#   repository_name  = "argo"
#   namespace        = "argocd"
#   create_namespace = true
#   version          = "7.0.0"

#   # Example values for ArgoCD
#   values = {
#     server = {
#       service = {
#         type = "LoadBalancer"
#       }
#     }
#   }
# }
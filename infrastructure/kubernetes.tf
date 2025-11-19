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
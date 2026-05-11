locals {
  kubeconfig_path = "/tmp/${module.kubernetes.cluster_name}-kubeconfig"
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

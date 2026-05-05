output "kubeconfig" {
  description = "Kubeconfig content for the Civo Kubernetes cluster."
  value       = module.kubernetes.kubeconfig
  sensitive   = true
}

output "cluster_name" {
  description = "Name of the Civo Kubernetes cluster."
  value       = module.kubernetes.cluster_name
}

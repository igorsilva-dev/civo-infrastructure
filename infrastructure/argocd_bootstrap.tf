resource "kubectl_manifest" "root_app" {
  yaml_body = templatefile("${path.module}/manifests/root-app.yaml.tftpl", {
    repo_url      = "https://github.com/igorsilva-dev/k8s-gitops"
    revision      = "main"
    manifest_path = "applications"
  })

  validate_schema = false
  wait            = false

  depends_on = [module.argocd]
}

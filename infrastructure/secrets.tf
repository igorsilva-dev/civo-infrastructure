resource "kubernetes_secret" "doppler_token" {
  metadata {
    name      = "doppler-token-auth-api"
    namespace = module.namespaces.namespace_names["external-secrets"]
    labels = {
      "app.kubernetes.io/part-of"    = "external-secrets"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  type = "Opaque"

  data = {
    dopplerToken = var.doppler_token
  }
}

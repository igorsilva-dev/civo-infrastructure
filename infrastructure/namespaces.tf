module "namespaces" {
  source = "git::https://github.com/igorsilva-dev/tf-modules.git//kubernetes/namespaces-rbac?ref=v0.1.0"

  namespaces = [
    {
      name = "platform"
      labels = {
        "istio-injection"                    = "enabled"
        "pod-security.kubernetes.io/enforce" = "restricted"
        "app.kubernetes.io/part-of"          = "platform"
      }
    },
    {
      name = "agents"
      labels = {
        "istio-injection"                    = "enabled"
        "pod-security.kubernetes.io/enforce" = "baseline"
        "app.kubernetes.io/part-of"          = "agents"
      }
    },
    {
      name = "sandbox"
      labels = {
        "pod-security.kubernetes.io/enforce" = "privileged"
        "app.kubernetes.io/part-of"          = "sandbox"
      }
    },
    {
      name = "external-secrets"
      labels = {
        "app.kubernetes.io/part-of" = "external-secrets"
      }
    }
  ]

  depends_on = [module.kubernetes]
}

locals {
    backend_data = yamldecode(file("backend.yaml"))
    environment_data = yamldecode(file("environment.yaml"))
    access_keys = {
        access_key = get_env("CIVO_ACCESS_KEY")
        secret_key = get_env("CIVO_SECRET_KEY")
    }
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = merge(
    local.environment_data,
    local.backend_data,
    local.access_keys,
)

terraform {
    source = "../../../infrastructure"
}

generate "providers" {
    path = "providers.tf"
    if_exists = "overwrite"
    contents = <<EOF
terraform {
  required_providers {
    civo = {
      source  = "civo/civo"     # adjust to the correct registry path if needed
      version = "1.1.7"  
    }
  }
}
provider "civo" {
  region = "${local.environment_data["region"]}"
}
EOF
}


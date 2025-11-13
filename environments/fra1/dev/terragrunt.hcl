locals {   
    environment_data = yamldecode(file("environment.yaml"))    
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

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
      source  = "civo/civo"
    }
  }
}
provider "civo" {
  region = "${local.environment_data["region"]}"
}
EOF
}


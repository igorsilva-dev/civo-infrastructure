locals {
    backend_data = yamldecode(file("backend.yaml"))
    environment_data = yamldecode(file("environment.yaml"))
}

inputs = merge(
    local.environment_data,
    local.backend_data,
)

generate "providers" {
    path = "providers.tf"
    if_exists = "overwrite"
    contents = <<EOF
provider "civo" {
  region = "${local.environment_data["region"]}"
}
EOF
}

remote_state = {
    backend = "s3"
    generate = {
        path = "backend.tf"
        if_exists = "overwrite"
    }
    config = {
        bucket = local.backend_data["bucket_state_name"]
        key = local.backend_data["backend_key"]
        region = local.backend_data["backend_region"]
    }
}
locals {
    backend_data = yamldecode(file("backend.yaml"))
    environment_data = yamldecode(file("environment.yaml"))
}

inputs = merge(
    local.environment_data,
    local.backend_data,
)
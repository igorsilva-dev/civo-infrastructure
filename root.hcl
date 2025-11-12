
locals {    
    access_keys = {
        access_key = get_env("CIVO_ACCESS_KEY")
        secret_key = get_env("CIVO_SECRET_KEY")
    }
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  backend "s3" {
      endpoint                    = "https://objectstore.lon1.civo.com"
      bucket                      = "tf-store"
      key                         = "${path_relative_to_include()}/tofu.tfstate"
      region                      = "LON1"
      skip_region_validation      = true
      skip_credentials_validation = true
      skip_metadata_api_check     = true
      force_path_style            = true
      access_key = "${local.access_keys.access_key}"
      secret_key = "${local.access_keys.secret_key}"
  }
}
EOF
}
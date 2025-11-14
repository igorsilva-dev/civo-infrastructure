terramate {
  required_version = ">= 0.12.0"
  # required_version_allow_prereleases = true
  config {

    git {
      default_remote = "origin"
      default_branch = "main"
    }

    run {
      env {
        TF_PLUGIN_CACHE_DIR = "${terramate.root.path.fs.absolute}/.tf_plugin_cache_dir"
      }
    }

    # Enable Terramate Scripts
    experiments = [
      "scripts",
      "tmgen",
    ]
  }
}
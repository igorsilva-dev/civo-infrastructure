terramate {
  required_version = ">= 0.12.0"
  # required_version_allow_prereleases = true
  config {

    git {
      default_remote = "origin"
      default_branch = "main"
    }

    # Enable Terramate Scripts
    experiments = [
      "scripts",
      "tmgen",
    ]
  }
}
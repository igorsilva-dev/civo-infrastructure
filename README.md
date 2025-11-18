# civo-infrastructure

Infrastructure as Code for Civo Cloud using [Terragrunt](https://terragrunt.gruntwork.io/), [OpenTofu](https://opentofu.org/), and [Terramate](https://terramate.io/).

## Structure

- **infrastructure/**  
  Core Terraform/OpenTofu configuration and module usage.
- **environments/**  
  Environment-specific stacks (e.g., `lon1/dev`, `fra1/dev`) managed by Terragrunt and Terramate.
- **.github/workflows/**  
  CI/CD pipelines for preview, deployment, and destroy operations using GitHub Actions.

## Features

- Modular infrastructure managed with Terragrunt for DRY configuration.
- Environment separation (dev, prod, etc.) using Terramate stacks.
- Automated formatting, linting, plan, apply, and destroy via GitHub Actions.
- Provider: [Civo](https://www.civo.com/) (via `civo/civo` provider).
- Remote state stored in Civo Object Store (S3-compatible).
- Reusable modules sourced from [tf-modules](https://github.com/igorsilva-dev/tf-modules).

## Reusable Modules

This repository leverages [tf-modules](https://github.com/igorsilva-dev/tf-modules) for modular and reusable Terraform/OpenTofu components.  
Modules are sourced directly from the external repo using the `source` argument in module blocks.

### Example: Using the Network Module

```hcl
module "network" {
  source               = "git::https://github.com/igorsilva-dev/tf-modules.git//civo/network?ref=v2025.11.12.02"
  network_label        = "main_network"
  firewall_name        = "main_firewall"
  create_default_rules = true
}
```

- `source`: Specifies the module location and version (`ref`).
- `network_label`, `firewall_name`, `create_default_rules`: Example input variables for the network module.

### How to Use

1. **Reference the module** in your Terraform/OpenTofu configuration using the `source` URL and desired version tag.
2. **Pass required input variables** as defined by the module’s `variables.tf`.
3. **Reuse modules** for different environments or stacks by changing input values.

For available modules and input variables, see the [tf-modules repository](https://github.com/igorsilva-dev/tf-modules).

## Usage

### Prerequisites

- [Terragrunt](https://terragrunt.gruntwork.io/)
- [OpenTofu](https://opentofu.org/)
- [Terramate](https://terramate.io/)
- [asdf](https://asdf-vm.com/) (for tool version management)

### Environment Setup

1. Clone the repository.
2. Configure your environment variables for Civo credentials:
   ```sh
   export CIVO_ACCESS_KEY=your_access_key
   export CIVO_SECRET_KEY=your_secret_key
   ```
3. Navigate to your environment stack:
   ```sh
   cd environments/lon1/dev
   terragrunt init
   terragrunt plan
   terragrunt apply
   ```

### CI/CD

- **Preview:**  
  Runs `terramate list --changed` and `terragrunt plan` on changed stacks.
- **Deploy:**  
  Runs `terragrunt apply` on changed stacks.
- **Destroy:**  
  Destroys selected stacks via workflow dispatch.

Secrets (like `CIVO_ACCESS_KEY`) must be set in the GitHub repository settings for workflows.



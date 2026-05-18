# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for milestone releases. Day-to-day commits land on `main` continuously; milestone tags (`v0.1.0`, `v0.2.0`, etc.) mark phase completions of the [Portfolio Roadmap](https://github.com/igorsilva-dev).

## [Unreleased]

Phase 2 work begins after `v0.1.0`: Istio service mesh + Prometheus / Grafana observability. See the Portfolio Roadmap for the full plan.

## [0.1.0] — 2026-05-18

**Phase 1 — Civo Infrastructure Bootstrap.** First milestone release. A single `terragrunt apply` brings up a Civo K3s cluster, namespaces, Argo CD via Helm, and the root Argo CD Application that hands off everything else to [k8s-gitops](https://github.com/igorsilva-dev/k8s-gitops) via the app-of-apps pattern. External Secrets Operator integrates with Doppler so no plaintext secrets land in git.

### Added

- **Cluster + network bootstrap** (CIVO-001 / CIVO-002): consumes `civo/network` and `civo/kubernetes` from [tf-modules `v0.1.0`](https://github.com/igorsilva-dev/tf-modules/releases/tag/v0.1.0). Single-node K3s on `g4s.kube.medium` (2 vCPU / 4 GB / 50 GB) in `lon1`. `infrastructure/outputs.tf` exposes `kubeconfig` (sensitive) and `cluster_name`.
- **Namespace strategy** (CIVO-003): `platform`, `agents`, `sandbox`, `external-secrets` namespaces created via `tf-modules/kubernetes/namespaces-rbac`. Pod Security Standards labels (`restricted` / `baseline` / `privileged`) and Istio-injection labels in place ahead of Phase 2.
- **Provider stack** (CIVO-003): `kubernetes`, `helm`, and `kubectl` providers configured via parsed-kubeconfig (`yamldecode(module.kubernetes.kubeconfig)` → host + client cert/key) rather than `config_path`. Avoids the plan-time `stat` failures `config_path` produces on a single-stage apply.
- **Argo CD via Helm** (CIVO-004): chart `argo-cd 7.7.10` installed by Terraform `helm_release`, namespace `argocd`. Values pinned to a single-replica controller, ClusterIP service, no dex / notifications, `wait = false` so apply doesn't block on chart pod readiness.
- **Argo CD root Application** (CIVO-005): `kubectl_manifest "root_app"` (via `gavinbunney/kubectl`) creates a single Argo CD Application pointing at `https://github.com/igorsilva-dev/k8s-gitops` → `applications/`. After this, the cluster reconciles itself from the gitops repo.
- **External Secrets Operator bootstrap inputs** (CIVO-007): `external-secrets` namespace, `doppler-token-auth-api` Kubernetes Secret seeded from `var.doppler_token`, GitHub Actions workflows wired to expose `TF_VAR_doppler_token` from the `DOPPLER_TOKEN` repo secret. The operator install + ClusterSecretStore + ExternalSecrets live in [k8s-gitops](https://github.com/igorsilva-dev/k8s-gitops).
- **Documentation pass** (CIVO-008 / CIVO-009): full README rewrite with Mermaid architecture diagram + reproduction guide. `docs/architecture.md` (bootstrap order, provider auth pattern, Terragrunt `required_providers` placement, sync-wave hierarchy, three known issues). Three ADRs: Argo CD over Flux, ESO + Doppler over Sealed Secrets, separate gitops repo. `docs/cost.md` with current + Phase 2+ estimates (~$22/mo at Phase 1 sizing).

### Changed

- **Terragrunt is the sole orchestrator** (`191e2b0`): Terramate removed; `terragrunt run` invoked directly from CI. Source structure stayed; the matrix loop in the workflows replaced `terramate run --changed`.
- **CI matrix limited to `lon1/dev`** (`f3d076c`): `fra1/dev` lives on disk as a parked stack but isn't deployed by CI. Single-region for Phase 1 cost discipline.
- **K3s version pinned to `1.34.2-k3s1`** (`01a0bdc`): Civo deprecated `1.32.5-k3s1` and rejects it on cluster create. Verified against `civo kubernetes versions ls`.
- **Worker pool `g4s.kube.xsmall` → `g4s.kube.medium`** (CIVO-004 follow-up `46b31ec`): `xsmall` is 1 GB total, not 2 GB as the original Phase-1 cost note assumed. After K3s reservations only ~262 Mi was allocatable, which can't fit Argo CD core. Required a destroy + apply cycle because Civo doesn't accept in-place pool resize.
- **`required_providers` centralised in `infrastructure/versions.tf`** (CIVO-005 follow-up): the Terragrunt `generate "providers"` block emits only the env-specific `provider "civo" {}` block. Third-party providers (`gavinbunney/kubectl`) need explicit declaration that `pre-commit terraform_validate` can see in the source directory.
- **`tf-modules` ref bumped to `v0.1.0`** (CIVO-001) for `civo/network`, `civo/kubernetes`, and (later) to `v2026.05.11.02` for `helm` after that module's embedded provider block was removed.

### Fixed

- **Argo CD install timing out** (CIVO-004 follow-up `ef4127a`): the chart's `wait = true` default blocked Terraform on Argo CD pod readiness, which couldn't complete in 15 min on the small node. Set `wait = false`; pods come up async, terraform finishes in seconds, status verifiable via `kubectl get pods -n argocd`.
- **Terragrunt `generate "providers"` clobbering source providers** (`462b0e9`): the generate block writes `providers.tf` with `if_exists = "overwrite"`, silently dropping any provider config also named `providers.tf` in source. Renamed `infrastructure/providers.tf` to `infrastructure/kubernetes_provider.tf`; the kubernetes provider config now survives the cache copy.
- **`config_path` provider auth incompatible with single-stage apply** (`71adb74`): the kubernetes and helm providers validate `config_path` at plan time, but `local_file.kubeconfig` writes the kubeconfig only at apply time. Switched both providers (and later `kubectl`) to `host` + client cert/key parsed from the in-state kubeconfig string. Works on first apply and on destroy/recreate.
- **Helm tf-module embedded provider block** (in [`tf-modules` `v2026.05.11.02`](https://github.com/igorsilva-dev/tf-modules)): the module had its own `provider "helm" {}` block, which prevented callers from overriding it and forced `kubeconfig_path` to be a file on disk. Out-of-band fix released as `v2026.05.11.02`; this repo bumped the helm module ref accordingly.

### Notes

- **Reproducible from clean state**: a `terragrunt destroy` followed by `terragrunt apply` re-creates the entire platform end to end. CI verified.
- **Known issue (out of scope)**: `kubectl port-forward` is broken on K3s 1.34 + containerd 2.1.x. UI access uses `kubectl proxy` with a doubled URL; documented in [README.md](README.md#accessing-the-argo-cd-ui) and [docs/architecture.md](docs/architecture.md#k3s-134--containerd-21x-port-forward-regression). Phase 2 Istio + ingress will retire this workaround.
- **Pairs with [k8s-gitops `v0.1.0`](https://github.com/igorsilva-dev/k8s-gitops/releases/tag/v0.1.0)** and [tf-modules `v0.1.0`](https://github.com/igorsilva-dev/tf-modules/releases/tag/v0.1.0).

[Unreleased]: https://github.com/igorsilva-dev/civo-infrastructure/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/igorsilva-dev/civo-infrastructure/releases/tag/v0.1.0

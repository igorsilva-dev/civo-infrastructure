# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for milestone releases. Day-to-day commits land on `main` continuously; milestone tags (`v0.1.0`, `v0.2.0`, etc.) mark phase completions of the [Portfolio Roadmap](https://github.com/igorsilva-dev).

## [Unreleased]

Phase 2 work begins after `v0.1.0`: Istio service mesh + Prometheus / Grafana observability. See the Portfolio Roadmap for the full plan.

### Added

- **Tailscale device cleanup (EDGE-001).** The nightly teardown destroys the cluster through the Civo API, so the Tailscale operator never logs its devices out; every rebuild would leave offline duplicates and push names to `argocd-1`, `argocd-2`. `.github/scripts/tailscale-cleanup.sh` deletes every `tag:k8s-operator` / `tag:k8s` device through the Tailscale API (OAuth client credentials). `cluster-down.yaml` runs it after the destroy (before it, the running operator would re-register), and `cluster-up.yaml` before the apply to catch leftovers. Both steps are `continue-on-error` and skip when `TAILSCALE_OAUTH_CLIENT_ID` / `TAILSCALE_OAUTH_CLIENT_SECRET` aren't set. Untagged devices are never touched.

### Changed

- **Second worker node (PLAT-001).** `node_count` 1 → 2 on the `g4s.kube.medium` pool (Option B, decided 2026-09-09). One node has ~3 Gi allocatable and Argo CD alone uses ~1.2 Gi; the Phase 2 LGTM + Tailscale + Envoy Gateway stack adds an estimated 3.6–4.5 Gi. Two nodes also make multi-node scheduling and node-level chaos possible. The cluster is created with two nodes on the next Cluster Up.
- **Firewall locked down to the Kubernetes API (PLAT-002).** `main_firewall` used Civo's default rules, which allow **all** inbound TCP/UDP from `0.0.0.0/0`. Inbound is now `6443/tcp` only (kept open to `0.0.0.0/0` for the GitHub Actions runners; certificate-protected), plus everything from the network's own CIDR for node-to-node traffic. Outbound stays open. Uses the new `ingress_rules` input in tf-modules `civo/network`.
- **Removed the `istio-injection: enabled` labels** from `platform` and `agents`. Istio was parked when Phase 2 was reworked (2026-10-27); the labels did nothing.

- **Cluster lifecycle: up on demand, down every night.** `scale-to-zero.yaml` (down Friday, up Monday) is replaced by `cluster-up.yaml` (manual dispatch only) and `cluster-down.yaml` (daily at 21:00 Europe/Madrid, DST-aware via paired 19:00/20:00 UTC crons). Cluster Up re-enables the teardown workflow on every run, because GitHub had disabled the old schedule for 60 days of repo inactivity.
- **Teardown skips the Kubernetes API.** The nightly destroy removes `kubernetes_*` / `kubectl_manifest` / `helm_release` resources from state and destroys only the Civo cluster, network, and firewall. The 2026-07-17 destroy timed out with the `sandbox` namespace stuck in `Terminating`.
- **Merge-triggered apply only runs while the cluster is up**, so a merge never creates a cluster outside a work session.

### Fixed

- **Argo CD chart `7.7.10` → `10.11.6` (Argo CD v2.13 → v3.5.6) for Kubernetes 1.35.** After the K3s bump to `1.35.0-k3s1`, the `argocd`, `crashdummy` and `external-secrets` Applications went sync `Unknown`: Kubernetes 1.35 adds `.status.terminatingReplicas` to Deployments, and Argo CD 2.13's structured-merge diff fails on it (`field not declared in schema`). Argo CD 3.5 is tested against Kubernetes 1.33–1.36. Moved in lockstep with the self-managed `argocd` Application in k8s-gitops, so the Terraform bootstrap and the Application never pin different versions. The cluster is rebuilt on every Cluster Up, so this is a fresh install of 3.5, not an in-place upgrade across three chart majors. Chart 10 creates Argo CD's NetworkPolicies by default (ingress only; `argocd-server` open, repo-server and redis limited to Argo CD components, metrics open to all namespaces).
- **Nightly teardown moved off the top of the hour, with a backstop.** `cluster-down.yaml` now fires at 21:07 Madrid (`7 19`/`7 20` UTC) instead of 21:00, and again at 23:37 (`37 21`/`37 22` UTC). On 2026-10-26 the `0 20` run started 3.5 hours late and the `0 19` run never appeared: GitHub delays and drops scheduled runs most at :00. The backstop is a plain second destroy, a no-op on empty state, so a dropped run costs about two hours of cluster time instead of a full day.
- **K3s version bumped `1.34.2-k3s1` → `1.35.0-k3s1`.** Civo deprecated 1.34.2 and rejected every cluster create with `deprecated_cluster_version`, which is why all eight scheduled Monday bring-ups between 2026-07-27 and 2026-09-14 failed. Second forced bump after `1.32.5-k3s1`.

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

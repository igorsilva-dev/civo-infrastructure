# Architecture

Deep-dive on `civo-infrastructure`. The [root README](../README.md) covers what the repo does and how to use it; this document explains *why* it's shaped the way it is and what to know before changing it.

## Bootstrap order

A clean-state `terragrunt apply` walks the resources in this order. Terraform's DAG enforces it through the references; nothing is `depends_on`-only unless called out.

1. **`module.network`** — Civo network + firewall.
2. **`module.kubernetes`** — Civo K3s cluster, references `module.network.network_id` and `firewall_id`. Writes `kubeconfig` to state and to disk at `/tmp/${cluster_name}-kubeconfig` (the latter via the module's `local_file` resource when `write_kubeconfig = true`).
3. **`kubernetes` + `helm` + `kubectl` providers** are configured from `yamldecode(module.kubernetes.kubeconfig)` — extracting `host`, `cluster_ca_certificate`, `client_certificate`, `client_key`. Computed values become known the moment step 2 completes; nothing reads from `/tmp` (see Provider auth below).
4. **`module.namespaces`** — `platform`, `agents`, `sandbox`, `external-secrets`. Implicit reference through the kubernetes provider config means it runs after step 2/3.
5. **`kubernetes_secret.doppler_token`** — places the Doppler service token in the `external-secrets` namespace. References `module.namespaces.namespace_names["external-secrets"]` so it sequences after the namespace.
6. **`module.argocd`** — Helm release for Argo CD. Uses the `helm` provider; references `module.kubernetes.cluster_name` for `kubeconfig_path` (which the helm module embeds; see Known issues below for context on the tf-modules fix that removed the embedded provider block). `wait = false` so apply doesn't block on chart pod readiness.
7. **`kubectl_manifest.root_app`** — creates the `root-app` Argo CD `Application` CR pointing at `k8s-gitops/applications/`. `depends_on = [module.argocd]` enforces the order. After this resource exists, Argo CD takes over from Terraform for everything downstream.

After step 7, the cluster reconciles itself from `k8s-gitops`:

- `root-app` watches `applications/` → creates the `argocd`, `external-secrets`, and `external-secrets-config` Applications.
- `argocd` Application adopts the live Helm release (release name `argocd` matches the Terraform-installed one).
- `external-secrets` Application installs the ESO Helm chart (sync wave -2).
- `external-secrets-config` Application applies the `ClusterSecretStore` + `ExternalSecret`s (sync wave 0).

## Provider auth

All four providers (`civo`, `kubernetes`, `helm`, `kubectl`) live in `infrastructure/`:

- **`civo`**: configured by Terragrunt's `generate "providers"` block in `environments/<region>/<env>/terragrunt.hcl`, using the env-specific region. Credentials from `CIVO_ACCESS_KEY` / `CIVO_SECRET_KEY` env vars.
- **`kubernetes` / `helm` / `kubectl`**: configured in `infrastructure/kubernetes_provider.tf` from `yamldecode(module.kubernetes.kubeconfig)` — extract `host` + the three TLS fields directly. No path-based config.

### Why parsed-kubeconfig, not `config_path`

`config_path` is validated by both `hashicorp/kubernetes_manifest` and the helm provider at *plan* time — they call `stat` on the path. The file is only written during apply by `local_file.kubeconfig` inside `tf-modules/civo/kubernetes`. So `config_path` fundamentally cannot work in a single-stage apply on a fresh CI runner.

Parsed-kubeconfig works because `module.kubernetes.kubeconfig` is a known value at plan time once the cluster exists in state (or computed-then-resolved on the first apply, in which case Terraform's DAG defers provider use until after the cluster resource is created).

This pattern is repeated for `kubectl` provider with `load_config_file = false` so it doesn't try to merge with the CI runner's `~/.kube/config`.

## `required_providers` placement (Terragrunt pattern)

Provider declarations follow a specific split:

- `infrastructure/versions.tf` holds the `terraform { required_providers {...} }` block with **all** providers (civo, kubernetes, helm, kubectl). Lives in source so the pre-commit `terraform_validate` hook (which runs `terraform init` directly in `infrastructure/`, with no Terragrunt context) can resolve every provider — including third-party ones like `gavinbunney/kubectl` that don't auto-resolve.
- Terragrunt's `generate "providers"` in `environments/<region>/<env>/terragrunt.hcl` emits **only** the env-specific `provider "civo" {}` block. It does *not* declare `required_providers` (would collide with `versions.tf`).
- Provider config for kubernetes / helm / kubectl lives in `infrastructure/kubernetes_provider.tf` (kept out of `providers.tf` so it doesn't collide with Terragrunt's `if_exists = "overwrite"`).

The filename `providers.tf` is reserved for Terragrunt. Don't create one in source — it'll be silently overwritten in the cache.

## Sync-wave hierarchy

| Wave | Applications | Rationale |
|---|---|---|
| -2 | `external-secrets` | Installs the ESO chart + CRDs. Has to land before anything consumes `ClusterSecretStore` / `ExternalSecret`. |
| -1 | _(reserved)_ | For future operators whose CRDs anything else depends on (cert-manager, kyverno). |
| 0  | `argocd`, `external-secrets-config`, future workloads | Default wave. Includes Argo CD self-management (no dependency on the operators) and ESO runtime config (depends on ESO CRDs from wave -2 via retry-with-backoff). |
| +1 and beyond | _(reserved)_ | Consumers that need everything else healthy first. |

Sync waves between *Applications* are respected by Argo CD's root-app sync; within a single Application, the same annotation orders resources but with weaker guarantees (use only when one Application contains both CRDs and CRs of those CRDs, and even then, prefer separate Applications).

## Known issues

### K3s 1.34 + containerd 2.1.x `port-forward` regression

`kubectl port-forward` fails with `read: connection reset by peer` on this cluster. The kubelet's CRI port-forward implementation in containerd 2.1.x has a regression that affects every pod, not just Argo CD. Workaround documented in the [README's UI access section](../README.md#accessing-the-argo-cd-ui).

If a future K3s patch fixes containerd or Civo bumps to a fixed version, the `server.rootpath` and `server.basehref` values in [`k8s-gitops/argocd/values.yaml`](https://github.com/igorsilva-dev/k8s-gitops/blob/main/argocd/values.yaml) can be removed and the UI URL collapses back to the normal `port-forward` flow.

### Civo cluster pool resize is not in-place

Civo's API does not accept `size` changes on an existing K3s pool — returns `Size change for existing cluster is not available at this moment`. To bump node size, either:

1. **Cluster recycle** (current pattern, dev portfolio): dispatch the `destroy.yaml` workflow, then re-push to trigger `deployment.yaml`. ~5-10 minutes round-trip. Loses ephemeral cluster state; Argo CD CRDs and reconciled manifests come back on next sync.
2. **Add a new pool entry, drain the old one** (zero-downtime, more complex): change `pools` to two entries, wait for Argo CD to reschedule workloads, then remove the old entry in a follow-up. Not implemented; documented here for when Phase 2 has real workloads that can't tolerate downtime.

### Argo CD `automated.retry` doesn't re-evaluate against HEAD

When a synced revision is bad (e.g., wrong `apiVersion`), Argo CD's retry replays the same `operation` object with the same revision. Pushing a fix to git doesn't unstick the retry loop. Two options:

1. Force a refresh + manual sync via the UI (or `argocd app sync <name>`).
2. Delete the Application — `root-app` recreates it from HEAD within seconds. Safe if the live resources don't carry Argo CD's tracking label, which is true when they were applied via raw `kubectl` while debugging.

Encountered during the [CIVO-007 ESO v1beta1 → v1 fix](https://github.com/igorsilva-dev/k8s-gitops/pull/3).

## Cost

See [`cost.md`](cost.md) (lands in CIVO-009). Short version: ~$22/mo for the current 1-node `g4s.kube.medium` baseline.

## ADRs

- [`adr/0001-argocd-over-flux.md`](adr/0001-argocd-over-flux.md) — Why Argo CD.
- [`adr/0002-eso-over-sealed-secrets.md`](adr/0002-eso-over-sealed-secrets.md) — Why External Secrets Operator + Doppler.
- [`adr/0003-separate-gitops-repo.md`](adr/0003-separate-gitops-repo.md) — Why `k8s-gitops` is its own repo.

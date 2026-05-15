# ADR 0003: Separate `k8s-gitops` repo instead of `civo-infrastructure/gitops/`

## Status

Accepted — 2026-05-12 (CIVO-005 architectural revision; original Phase-1 plan had the gitops manifests under this repo).

## Context

Phase 1's original design (Phase-1.md as initially drafted) put GitOps manifests under `civo-infrastructure/gitops/` — a monorepo for both infrastructure and the workloads running on it. Easier to set up: single repo, single CI workflow, atomic commits across infra and apps.

When CIVO-005 was being scoped, the question came up explicitly: keep the monorepo, or split into a dedicated gitops repo?

## Decision

Move the gitops manifests to a separate repo: [`igorsilva-dev/k8s-gitops`](https://github.com/igorsilva-dev/k8s-gitops) (public).

`civo-infrastructure` keeps the bootstrap (the `root-app` Argo CD Application is created here via `kubectl_manifest`), but everything that Argo CD reconciles lives in `k8s-gitops`.

## Consequences

### Positive

- **Matches production GitOps patterns**: real organizations almost universally separate infra (terraform, cluster lifecycle) from apps (k8s manifests, helm values). Reviewer audiences expect this split.
- **Separate review / approval paths**: changing how the cluster is provisioned (resize a node, bump K3s version) goes through one PR queue; adding a workload goes through another. Different stakeholders can own each.
- **Survives infra destroy/recreate**: the gitops repo is unaffected when `terragrunt destroy` blows away the cluster. After re-apply, Argo CD picks up exactly where it left off because the desired state is still there in git.
- **Models the team boundary**: in a real org, platform engineers own infra; app teams own their workloads. The two-repo split makes that boundary explicit even when one person owns both.
- **Argo CD's `repoURL` is naturally a separate URL**: pointing at a separate repo is a one-line change in the `root-app` template, with no path gymnastics or directory-include filters.

### Negative

- **Cross-repo changes for features that touch both** (e.g., adding External Secrets in CIVO-007): two PRs to coordinate. Solved by sync waves + Argo CD's retry semantics — order of merge doesn't matter, eventual consistency reconciles everything.
- **One more repo to manage** (releases, branches, README, etc.). For a solo portfolio that's negligible; it's an obvious cost in larger team contexts.
- **The bootstrap repo references a hardcoded URL** to the gitops repo (`https://github.com/igorsilva-dev/k8s-gitops` in `infrastructure/manifests/root-app.yaml.tftpl`). Forking requires editing that template. Acceptable for a portfolio; in a product environment you'd parameterize.

## Alternatives considered

- **Monorepo** (`civo-infrastructure/gitops/`): simpler to bootstrap, single PR for cross-cutting changes. Rejected for the production-pattern fit and team-boundary modeling above.
- **Per-app repo** (`argocd-config`, `eso-config`, `monitoring-config`, …): closer to the "ApplicationSet + repo-per-team" pattern at scale. Rejected as over-engineering for a single-developer portfolio; the single `k8s-gitops` repo already separates concerns cleanly via the `applications/`, `argocd/`, `external-secrets/` subdirectories.

## References

- [civo-infrastructure#15](https://github.com/igorsilva-dev/civo-infrastructure/pull/15) — root-app `kubectl_manifest` introduction.
- [k8s-gitops](https://github.com/igorsilva-dev/k8s-gitops) — the repo this ADR is about.

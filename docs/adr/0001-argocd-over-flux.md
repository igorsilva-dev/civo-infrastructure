# ADR 0001: Argo CD over Flux

## Status

Accepted — 2026-05-11 (CIVO-004).

## Context

The portfolio cluster needs a GitOps controller to reconcile manifests from `k8s-gitops` to the live K3s cluster. The two mature CNCF Graduated choices are Argo CD and Flux. Both are production-grade, both have strong communities, both can implement an app-of-apps pattern.

The portfolio is explicitly aimed at being demoable to hiring managers — a graphical UI that visualizes the reconciliation state is high-leverage. Phase 4 of the roadmap installs `kagent`, which has a richer ecosystem on the Argo CD side.

## Decision

Use Argo CD.

## Consequences

### Positive

- **Demo-friendly UI**: out-of-the-box dashboard shows Applications, sync status, resource tree, drift, and logs. Easier to walk a recruiter through "here's what's running and where it came from" than via Flux's CLI-first interface.
- **App-of-apps pattern is first-class**: documented, well-trodden. Our `root-app` + per-component Application split fits the Argo CD model natively.
- **`ApplicationSet` for Phase 4**: lets `kagent` generate Applications from templates without code changes here.
- **`ServerSideApply` sync option**: handles large CRDs (Argo CD's own, ESO's) without the client-side-apply "annotation too long" failure.
- **Multi-source Applications** (since v2.6): chart from upstream Helm repo + values from our gitops repo via `$values` ref — exactly what we use for self-management and ESO.

### Negative

- **Larger operational footprint**: server, repo-server, application-controller, applicationset-controller, redis, plus optional dex / notifications / cmp-server. Flux ships as a smaller set of controllers (~3 pods). On a single-node `g4s.kube.medium` (4 GB), Argo CD eats ~1 GB; Flux would have been ~300 MB.
- **More moving parts to learn**: Argo CD's CRD surface is bigger (Application, ApplicationSet, AppProject, ClusterDecisionGenerator, …). For a single-developer portfolio that's a feature for the resume; in a team org it's a tax.
- **Self-management bootstrap is non-trivial**: Argo CD has to be Helm-installed by Terraform first, then a `kubectl_manifest` creates a self-referencing Application. Documented in [`architecture.md`](../architecture.md). Flux's `flux bootstrap` command does this more cleanly, but it expects to own the gitops repo's structure — Phase 1 architecture prefers explicit control.

## Alternatives considered

- **Flux**: smaller footprint, cleaner self-bootstrap. Rejected primarily for the UI gap (portfolio demos) and the kagent ecosystem alignment in Phase 4.
- **No GitOps, just `terraform apply`**: rejected. The whole point of Phase 1 is to demonstrate GitOps as the reconciliation pattern.
- **ArgoCD Autopilot**: layered tool on top of Argo CD that automates the bootstrap. Rejected because the manual bootstrap is portfolio-narrative material — proving the pattern by writing it.

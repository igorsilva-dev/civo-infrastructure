# ADR 0002: External Secrets Operator + Doppler over Sealed Secrets

## Status

Accepted — 2026-05-14 (CIVO-007).

## Context

Secrets need to live somewhere other than plaintext in git. The two well-trodden CNCF-adjacent options for a small portfolio cluster:

- **Sealed Secrets** (Bitnami): asymmetric crypto. Encrypt secrets locally with the controller's public key, commit the ciphertext to git, the controller decrypts at apply time. Secrets effectively live in git, just unreadable without the cluster's private key.
- **External Secrets Operator (ESO)**: pulls secret values at runtime from an external secret store (Doppler, Vault, AWS Secrets Manager, etc.). Secrets never touch git. The cluster only needs the credentials to talk to the store.

Both approaches keep plaintext out of git. The differences are in operational model and where the source of truth lives.

## Decision

Use External Secrets Operator with Doppler as the backend.

## Consequences

### Positive

- **Secrets never go through git**, even encrypted. The full audit trail of "who changed what value when" lives in Doppler's own UI, which has activity logs, role-based access, and multi-environment scoping out of the box.
- **Rotation is trivial**: edit the value in Doppler, ESO picks it up on its next reconciliation (default 1h, configurable per-ExternalSecret via `refreshInterval`). No git push, no Argo CD sync, no cluster restart.
- **Multi-cluster portability later**: if Phase 2+ adds a second region or environment, the same Doppler project / config can serve both. Sealed Secrets ties each ciphertext to one cluster's key — a second cluster needs re-encryption.
- **Doppler free tier covers Phase 1**: project + config + service tokens, no card required.
- **Bootstrap is bounded**: exactly one secret has to exist in the cluster before ESO can run (the Doppler service token itself). Terraform manages that one Secret; every other secret flows through ESO from then on. The boundary is clear.

### Negative

- **External dependency**: Doppler outage = ESO can't refresh secrets. Cached values in existing Kubernetes Secrets keep working, so workloads don't immediately break, but rotation is blocked. For a portfolio that's fine; for production-critical workloads, multi-backend (Doppler + Vault failover) would be worth considering.
- **The bootstrap token is still a Terraform-managed secret**, which means it has to exist somewhere as a TF var. Currently in GitHub Actions secrets as `DOPPLER_TOKEN`. Not in git, but it's still "another secret in another place to manage." Sealed Secrets would have a similar shape (the controller's private key has to exist on the cluster).
- **Doppler is proprietary SaaS** (free tier today, no guarantee tomorrow). Sealed Secrets is fully open-source and self-hosted. If Doppler ever became unusable, we'd need to swap to AWS Secrets Manager, Vault, or another backend — but the `ClusterSecretStore` provider abstraction means only one file changes.

## Alternatives considered

- **Sealed Secrets**: simpler bootstrap (no external dep), fully self-hosted. Rejected for the rotation friction (every change is a git PR), the secrets-still-live-in-git aesthetic, and the multi-cluster portability gap.
- **HashiCorp Vault** (as the backend, with ESO in front): the production answer. Rejected for Phase 1 because operating a Vault cluster is a project unto itself; Doppler is the right "managed service" choice at this scale. Easy to swap in later — only the `ClusterSecretStore` provider block changes.
- **No secrets management at all** (kubectl create secret + don't commit): rejected. Defeats the GitOps single-source-of-truth premise.

## References

- [CIVO-007 PR pair](https://github.com/igorsilva-dev/civo-infrastructure/pull/16) — Terraform-side seed.
- [k8s-gitops#2](https://github.com/igorsilva-dev/k8s-gitops/pull/2) — ESO installation + Doppler ClusterSecretStore.
- [k8s-gitops#3](https://github.com/igorsilva-dev/k8s-gitops/pull/3) — ESO CRD `served=false` on `v1beta1`; bumped manifests to `v1`. Worth knowing before authoring new ESO manifests.

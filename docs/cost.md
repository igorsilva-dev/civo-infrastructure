# Cost

Monthly USD estimate for the Phase 1 portfolio deployment on Civo. Sourced from current Civo published pricing; verify against the live Civo billing dashboard before assuming the totals are exact. Phase 2+ revisions will land alongside the components they introduce.

## Current footprint (Phase 1, lon1/dev)

| Item | Detail | Estimate |
|---|---|---|
| K3s cluster (compute) | 1 × `g4s.kube.medium` (2 vCPU, 4 GB RAM, 50 GB SSD) | ~$20/mo |
| Network | 1 Civo network | $0 |
| Firewall | Default firewall with K8s API rules | $0 |
| Civo Object Store | `tf-backend` bucket for Terragrunt remote state (< 1 GB) | $0-2/mo |
| Doppler | `k8s-codeup` project, free tier (1 project, 3 configs, single user) | $0 |
| Argo CD UI exposure | ClusterIP only; access via `kubectl proxy` | $0 |
| **Total** | | **~$20-22/mo** |

The cluster is the only non-trivial line. Everything else is free at portfolio scale.

## Why `g4s.kube.medium` and not something smaller

The original Phase-1 cost note assumed `g4s.kube.xsmall` was 2 GB — Civo's published spec calls it "1 vCPU, 1 GB, 30 GB SSD" in practice. After K3s reservations the node had only ~262 Mi allocatable, which couldn't fit the Argo CD core (server + repo-server + controller + redis + applicationset-controller = ~1.2 Gi). The pods went to `Pending` with the node tainted `node.kubernetes.io/memory-pressure:NoSchedule`. Bumping to `g4s.kube.medium` (2 vCPU / 4 GB / 50 GB) gave ~3 Gi allocatable, which fits Argo CD comfortably and leaves headroom for Phase 2 components.

Civo's API does not allow in-place pool resize, so the bump required a destroy + apply cycle. Documented in [`architecture.md`](architecture.md#civo-cluster-pool-resize-is-not-in-place).

## Cost-down options

- **Destroy when not demoing.** Dispatch the `Terraform Destroy` GitHub Actions workflow. Cluster and worker disappear; the Object Store bucket persists (Terragrunt state survives). Brings the bill to ~$1-2/mo while idle. Re-apply via a push to `main`. ~5 minutes round-trip.
- **Single environment.** `environments/fra1/dev` exists on disk but is not in the CI deploy matrix; only `lon1/dev` is active. Re-enabling fra1 doubles the cluster line (~$40/mo total compute). Phase 2+ may want it for cross-region GitOps demos; Phase 1 stays single-region.
- **`g4s.kube.small` instead of medium.** 1 vCPU / 2 GB at ~$10/mo. Saves ~$10/mo. Argo CD core *barely* fits at 2 GB; Phase 2 Istio adds ~500 Mi and would push it over. Trade-off: smaller bill but a second resize before Phase 2.

## Phase 2+ forecast

| Phase | Component | Estimated additional memory | Estimated additional cost |
|---|---|---|---|
| 2 | Istio control plane + sidecars | ~500 Mi | $0 (fits on existing node) |
| 2 | kube-prometheus-stack | ~1 Gi | $0 if still fits; +$20/mo if a second node added |
| 3 | First AI agent (single replica, modest) | ~256 Mi | $0 |
| 4 | kagent operator + tools | ~500 Mi | likely $0 |
| 5 | Multi-agent + gVisor sandbox | ~1+ Gi | likely needs bump to `g4s.kube.large` (~$40/mo) or 2-node `medium` pool |

Hard guess at Phase 5 cluster: 1 × `g4s.kube.large` (4 vCPU / 8 GB / 60 GB) ≈ **~$40/mo**, plus a small bump for additional Object Store reads/writes. Still in coffee-money territory for a working K8s + AI agents platform.

## Out-of-pocket so far

The Civo signup credit (typically $250 at the time of writing) covers Phase 1 for ~11 months at the current burn rate. Phase 2-5 should all stay within that budget if cluster sizing stays at `medium` or `large`.

## What this excludes

- Domain name (~$10-15/year for a `.dev` if you want a public hostname; deferred to Phase 2 with Istio + ingress).
- Outbound bandwidth (Civo's first 1 TB/region/month is free; portfolio cluster won't approach this).
- Civo egress fees for Object Store API calls (negligible at portfolio scale; CI runs ~20-30 plans/applies per month, well under any threshold).
- LoadBalancer ($10/mo each on Civo when used). Phase 1 stays ClusterIP; Phase 2 adds one when Istio ingress comes online.

## Verification

```sh
# In a billing tab on the Civo dashboard, the current month line items
# should sum to approximately the table above. Discrepancies in 2026 dollars
# are likely Civo pricing updates rather than infrastructure changes.
```

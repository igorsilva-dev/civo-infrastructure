# Cost

Monthly USD cost of the lab on Civo. Prices from [Civo's pricing page](https://www.civo.com/pricing), checked 2026-10-31; the Civo billing dashboard is the invoice.

## Current footprint (lon1/dev)

| Item | Detail | Price | Per month |
|---|---|---|---|
| K3s cluster (compute) | 2 × `g4s.kube.large` (4 vCPU, 8 GB RAM, 60 GB SSD each) | $0.059524/h per node | ~$86.90 if run 24/7; billed per hour actually up (see below) |
| Civo Object Store | `tf-backend` bucket for Terragrunt remote state | $0.000015/GB-hour, **allocated in 500 GB blocks** | **$5.43, always**: the state is under 1 GB, but the bucket bills as a full 500 GB block whether the cluster is up or not |
| Control plane | K3s API server and management | Free | $0 |
| Network, firewall | 1 Civo network, `main_firewall` | Free | $0 |
| Data transfer | Ingress and egress | Free | $0 |
| Doppler | `k8s-codeup` project, free tier (1 project, 3 configs, single user) | Free | $0 |
| Tailscale | Personal plan: tailnet, operator, HTTPS certificates | Free | $0 |
| Argo CD UI exposure | Tailscale Ingress (tailnet only, no load balancer) | Free | $0 |
| **Total** | | | **$5.43 floor + about $0.12 per hour the cluster is up** (~$92 if it ran 24/7) |

Two lines matter: the Object Store bucket, a fixed $5.43 every month, and the cluster, billed only for the hours it exists. Everything else is free at portfolio scale.

## Actual: October 2026

Measured from the Cluster Up and Cluster Down runs (session start to end of the destroy) and Civo's charges API, on 2026-10-31 with that day's session still running (the month closes at about $7):

| Line | Usage | Cost |
|---|---|---|
| Cluster compute | 4 sessions, ~27 cluster-hours, ~42 node-hours | ~$1.26 |
| Object Store | `tf-backend`, 500 GB block, all month | ~$5.58 |
| **Total** | | **~$6.84 so far** |

The Object Store is over 80% of the bill. A typical 3-hour session on 2 Medium nodes cost about $0.18; the most expensive one in October was a 15-hour day with a late teardown (~$0.88).

## Node size

### Large, from Phase 2 (November 2026)

Measured on 2026-11-09 with OBS-001 running (Alloy, kube-state-metrics, node-exporter), from the kubelet's stats: a `g4s.kube.medium` node has **2,308 Mi allocatable**, not the ~3 Gi assumed below, so the 2-node cluster has about 4.5 GiB. About 2.6 GiB of it was already in use: ~1.5 GiB on the node running Argo CD's application controller (430-525 Mi on its own) and ~1.1 GiB on the other. Mimir, Loki and Tempo were estimated at another ~3.1-4 Gi, which doesn't fit.

| Option | Allocatable | Per hour | Verdict |
|---|---|---|---|
| 2 × Medium | ~4.5 GiB (measured) | $0.060 | Doesn't fit LGTM |
| 3 × Medium | ~6.75 GiB | $0.089 | Fits with almost no margin |
| **2 × Large** | ~10.4 GiB (measured) | $0.119 | Chosen: about double what Phase 2 needs |

Measured on 2026-11-11 on the first Large cluster: **5,327 Mi allocatable per node** (7.39 GiB capacity, 3.87 of 4 CPUs), so about 2 GiB of each node goes to K3s and the system reserve, a little less than on Medium in proportion. With the same workloads as above, the cluster used ~1.8 GiB (~0.7 GiB and ~1.1 GiB per node, the second with Argo CD's application controller at ~490 Mi). LGTM's ~3.1–4 Gi brings that to roughly 5–6 GiB of 10.4.

Large costs about $0.18 more per 6-hour session than three Mediums, and the size change is free in practice because the cluster is rebuilt from scratch every session. Fewer, bigger nodes mean losing one node takes out more, which matters less here than headroom.

### Medium, from Phase 1

The original Phase-1 cost note assumed `g4s.kube.xsmall` was 2 GB — Civo's published spec calls it "1 vCPU, 1 GB, 30 GB SSD" in practice. After K3s reservations the node had only ~262 Mi allocatable, which couldn't fit the Argo CD core (server + repo-server + controller + redis + applicationset-controller = ~1.2 Gi). The pods went to `Pending` with the node tainted `node.kubernetes.io/memory-pressure:NoSchedule`. Bumping to `g4s.kube.medium` (2 vCPU / 4 GB / 50 GB) fit Argo CD comfortably; its allocatable, measured later, is 2,308 Mi, not the ~3 Gi this note first assumed.

Civo's API does not allow in-place pool resize, so the bump required a destroy + apply cycle. Documented in [`architecture.md`](architecture.md#civo-cluster-pool-resize-is-not-in-place).

## Cost-down options

- **Up on demand, down every night (in place).** The cluster is created with the `Cluster Up` workflow when there is work to do and destroyed by `cluster-down.yaml` from 18:07 Madrid time every night (scheduled early to absorb GitHub's 3 to 4 hour cron delay), with a 20:37 backstop in case GitHub drops the first scheduled run. The Object Store bucket persists (Terragrunt state survives), so idle cost is the bucket's $5.43/mo and the cluster line is billed per hour actually used: about $0.12 per hour on 2 Large nodes, so a 2-hour session costs about $0.24. GitHub starts the nightly runs 3 to 5 hours late, which is why the schedule is early; a late teardown costs about $0.12 per extra hour, not dollars. Any dynamically provisioned Civo volume (PVC) or LoadBalancer outlives the destroy and keeps billing, so workloads stay on `emptyDir` and LoadBalancers must be checked after teardown.
- **Single environment.** `environments/fra1/dev` exists on disk but is not in the CI deploy matrix; only `lon1/dev` is active. Re-enabling fra1 doubles the cluster line per hour; the state bucket is shared, so the fixed cost stays the same. Phase 2+ may want it for cross-region GitOps demos; Phase 1 stays single-region.
- **Smaller nodes.** `g4s.kube.medium` halves the per-hour rate but can't hold Phase 2 on two nodes (see Node size), and `g4s.kube.small` (2 GB) barely fits the Argo CD core. Smaller nodes would mean more of them; at on-demand hours the saving is cents per session. Not worth it.
- **Move the state off Civo Object Store.** The bucket is the only always-on cost. A backend with a free tier would take idle cost to $0, at the price of a state migration and another credential to manage. At $5.43/mo it isn't worth doing yet; it's the first lever if the bill ever matters.

## Phase 2+ forecast

Phase 2 (observability and a private edge) changes the per-hour rate, not the fixed cost:

| Phase | Change | Cost impact |
|---|---|---|
| 2 | Second `g4s.kube.medium` (PLAT-001, done) | Compute per hour doubles: ~$0.03 → ~$0.06/h |
| 2 | 2 × `g4s.kube.large` instead of Medium (memory measured with OBS-001) | Compute per hour doubles again: ~$0.06 → ~$0.12/h |
| 2 | Tailscale private edge (EDGE) | $0: the proxies are tailnet devices, not Civo load balancers |
| 2 | Envoy Gateway on `loadBalancerClass: tailscale` | $0: no Civo load balancer |
| 2 | LGTM (Mimir, Loki, Tempo, Grafana) on `emptyDir` | $0 on top of the Large nodes |
| 3-5 | AI agents, kagent, gVisor sandbox | Possibly a third Large node (~$0.06/h): per hour, still cents per session |

Persistent volumes stay off the table while the cluster is destroyed nightly: they'd outlive the destroy and bill at $0.000149/GB-hour.

## Out-of-pocket so far

October 2026, the first full month of on-demand usage: about $7, most of it the state bucket. At this rate any Civo signup credit lasts far longer than this note's original estimate of ~11 months.

## What this excludes

- Domain name (~$10-15/year for a `.dev` if you want a public hostname; not needed while everything is reached through tailnet names; only a deliberate public demo would need one).
- Data transfer: free and unlimited on Civo.
- Civo egress fees for Object Store API calls (negligible at portfolio scale; CI runs ~20-30 plans/applies per month, well under any threshold).
- LoadBalancer ($0.014881/h, $10.86/mo per 10,000 concurrent requests). None in use: Phase 2 routes through Tailscale instead, and a Civo LB would outlive the nightly destroy.

## Verification

- **Invoice:** the billing page on the Civo dashboard.
- **Usage, from the API:** `GET https://api.civo.com/v2/charges?from=<ISO>&to=<ISO>` with the API key as a bearer token returns each billed item with its hours (no prices). Its node records lag behind real usage by days, so session times from the Cluster Up / Cluster Down runs are the better live measure.
- **Prices:** [civo.com/pricing](https://www.civo.com/pricing). If they change, update the table above.

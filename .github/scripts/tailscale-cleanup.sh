#!/usr/bin/env bash
# Deletes the cluster's devices from the tailnet: everything tagged tag:k8s-operator (the operator)
# or tag:k8s (the proxies it creates). The nightly teardown destroys the cluster through the Civo
# API, so the operator never logs its devices out; without this, every rebuild would leave offline
# duplicates and push names to argocd-1, argocd-2, ...
#
# Untagged devices (laptops, phones) never match. Skips quietly when the OAuth credentials aren't
# configured, so the lifecycle workflows keep working before Tailscale is set up.
set -euo pipefail

if [[ -z "${TS_OAUTH_CLIENT_ID:-}" || -z "${TS_OAUTH_CLIENT_SECRET:-}" ]]; then
  echo "::notice::Tailscale OAuth credentials not set; skipping device cleanup."
  exit 0
fi

api="https://api.tailscale.com/api/v2"
token="$(curl -fsS "$api/oauth/token" \
  -d "client_id=$TS_OAUTH_CLIENT_ID" \
  -d "client_secret=$TS_OAUTH_CLIENT_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')"
echo "::add-mask::$token"

devices="$(curl -fsS -H "Authorization: Bearer $token" "$api/tailnet/-/devices" |
  jq -r '.devices[]
    | select((.tags // []) | any(. == "tag:k8s-operator" or . == "tag:k8s"))
    | "\(.nodeId) \(.hostname)"')"

if [[ -z "$devices" ]]; then
  echo "No cluster devices in the tailnet."
  exit 0
fi

while read -r node_id hostname; do
  curl -fsS -X DELETE -H "Authorization: Bearer $token" "$api/device/$node_id" >/dev/null
  echo "Deleted $hostname ($node_id)"
done <<<"$devices"

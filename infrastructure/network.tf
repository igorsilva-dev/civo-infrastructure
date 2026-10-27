# Inbound is the Kubernetes API only. It stays open to 0.0.0.0/0 because the GitHub Actions runners
# apply through it (their IPs are too many and change), and it requires client certificates.
# Traffic from the network itself (node to node) and all outbound stay allowed by the module.
module "network" {
  source        = "git::https://github.com/igorsilva-dev/tf-modules.git//civo/network?ref=v2026.10.27.01"
  network_label = "main_network"
  firewall_name = "main_firewall"

  ingress_rules = [
    { label = "kubernetes-api", port_range = "6443", cidr = ["0.0.0.0/0"] },
  ]
}

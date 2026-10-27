# Inbound is the Kubernetes API only. It stays open to 0.0.0.0/0 because the GitHub Actions runners
# apply through it (their IPs are too many and change), and it requires client certificates.
# Traffic from the network itself (node to node) and all outbound stay allowed by the module.
module "network" {
  # TODO: pin to the tf-modules rolling tag once tf-modules#16 merges (PLAT-002).
  source        = "git::https://github.com/igorsilva-dev/tf-modules.git//civo/network?ref=a9e2d706982f9651c6d90a1d0f900c898773d898"
  network_label = "main_network"
  firewall_name = "main_firewall"

  ingress_rules = [
    { label = "kubernetes-api", port_range = "6443", cidr = ["0.0.0.0/0"] },
  ]
}

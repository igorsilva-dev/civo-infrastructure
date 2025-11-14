module "network" {
  source       = "git::https://github.com/igorsilva-dev/tf-modules.git//civo/network?ref=v2025.11.12.02"
  network_label = "main_network"
  firewall_name  = "main_firewall"
  create_default_rules = true
}

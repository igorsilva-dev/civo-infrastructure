module "civo_network" {
  source       = "git::https://github.com/igorsilva-dev/tf-modules/civo/network?ref=v2025.11.05.01"
  network_label = "main_network"
  firewall_name  = "main_firewall"
  create_default_rules = true
}
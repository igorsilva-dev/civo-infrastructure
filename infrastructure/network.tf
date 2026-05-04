module "network" {
  source               = "git::https://github.com/igorsilva-dev/tf-modules.git//civo/network?ref=v0.1.0"
  network_label        = "main_network"
  firewall_name        = "main_firewall"
  create_default_rules = true
}

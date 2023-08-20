provider "kubernetes" {
  # config_path    = "${local.home_stack_config}/k0s.config"
  config_path = "./k0s.config"
  config_context = "k0s"
}

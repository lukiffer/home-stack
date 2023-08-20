provider "kubernetes" {
  config_path    = "${local.home_stack_root}/k0s.config"
  config_context = "k0s"
}

locals {
  # Kubernetes variables
  kubernetes_namespace     = "home-automation"

  # Node-local file paths
  home_stack_root          = "/opt/home-stack"
  home_stack_source        = "${local.home_stack_root}/source"
  home_stack_config        = "${local.home_stack_root}/config"

  # Network configuration
  home_assistant_node_port = 30000
  node_red_node_port       = 30100
  grafana_node_port        = 30200
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = local.kubernetes_namespace
  }
}

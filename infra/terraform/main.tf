terraform {
  backend "local" {
    path = "/opt/home-stack/config/terraform.tfstate"
  }
}

locals {
  # Kubernetes variables
  kubernetes_namespace     = "home-automation"

  # Node-local file paths
  home_stack_root          = "/opt/home-stack"
  home_stack_source        = "${local.home_stack_root}/source"
  home_stack_config        = "${local.home_stack_root}/config"

  # Cross-pod shared secrets
  secrets = yamldecode(file("${local.home_stack_config}/home-assistant/secrets.yaml"))

  # Network configuration
  home_assistant_node_port = 30000
  mariadb_node_port        = 30100
  node_red_node_port       = 30200
  zwave_js_http_node_port  = 30210
  zwave_js_ws_node_port    = 30211
  grafana_node_port        = 30300
  nginx_node_port          = 32767
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = local.kubernetes_namespace
  }
}

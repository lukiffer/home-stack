module "grafana" {
  source = "./modules/kubernetes-deployment"

  name            = "grafana"
  namespace       = resource.kubernetes_namespace.namespace.metadata[0].name
  container_image = "grafana/grafana:latest"

  labels = {
    app   = "grafana"
    stack = "home-stack"
  }

  env = {
    GF_SECURITY_ADMIN_USER = local.secrets.grafana_security_admin_username,
  }

  ports = [{
    name           = "grafana-http",
    container_port = 3000,
    node_port      = local.grafana_node_port,
  }]

  local_config_path = "${local.home_stack_config}/grafana/"
  config_mount_path = "/var/lib/grafana"
}


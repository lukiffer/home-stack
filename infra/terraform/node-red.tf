module "node_red" {
  source = "./modules/kubernetes-deployment"

  name            = "node-red"
  namespace       = resource.kubernetes_namespace.namespace.metadata[0].name
  container_image = "lukiffer/node-red-home-assistant:latest"

  labels = {
    app   = "node-red"
    stack = "home-stack"
  }

  env = {
    NODE_RED_CREDENTIAL_SECRET = local.secrets.node_red_credential_secret,
  }

  ports = [{
    name           = "node-red-http"
    container_port = 1880,
    node_port      = local.node_red_node_port,
  }]

  local_config_path = "${local.home_stack_config}/node-red/"
  config_mount_path = "/data/"
}

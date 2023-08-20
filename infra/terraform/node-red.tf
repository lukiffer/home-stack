module "node_red" {
  source = "./modules/kubernetes-deployment"

  name            = "node-red"
  namespace       = resource.kubernetes_namespace.namespace.metadata[0].name
  container_image = "nodered/node-red:latest"

  post_start_command = [
    "npm",
    "install",
    "node-red-contrib-stoptimer",
    "node-red-contrib-time-range-switch",
    "node-red-contrib-home-assistant-websocket",
  ]

  labels = {
    app   = "node-red"
    stack = "home-stack"
  }

  env = {
    NODE_RED_CREDENTIAL_SECRET = local.secrets.node_red_credential_secret,
  }

  container_port = 1880
  node_port      = local.node_red_node_port

  local_config_path = "${local.home_stack_config}/node-red/"
  config_mount_path = "/data/"
}

module "home_assistant" {
  source = "./modules/kubernetes-deployment"

  name            = "home-assistant"
  namespace       = resource.kubernetes_namespace.namespace.metadata[0].name
  container_image = "homeassistant/home-assistant"

  labels = {
    app   = "home-assistant"
    stack = "home-stack"
  }

  container_port = 8123
  node_port      = local.home_assistant_node_port

  local_config_path = "${local.home_stack_config}/home-assistant/"
}

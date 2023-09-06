module "home_assistant" {
  source = "./modules/kubernetes-deployment"

  name            = "home-assistant"
  namespace       = resource.kubernetes_namespace.namespace.metadata[0].name
  container_image = "homeassistant/home-assistant:stable"
  privileged      = true

  labels = {
    app   = "home-assistant"
    stack = "home-stack"
  }

  env = {
    DISABLE_JEMALLOC = "true",
  }

  ports = [{
    name           = "home-assistant-http",
    container_port = 8123
    node_port      = local.home_assistant_node_port
  }]

  local_config_path = "${local.home_stack_config}/home-assistant/"

  host_device_mounts = [
    "/dev/ttyUSB1",
    "/dev/ttyUSB2",
  ]
}

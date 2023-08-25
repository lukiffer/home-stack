module "zwave_js" {
  source = "./modules/kubernetes-deployment"

  name            = "zwave-js"
  namespace       = resource.kubernetes_namespace.namespace.metadata[0].name
  container_image = "zwavejs/zwave-js-ui:latest"

  labels = {
    app   = "zwave-js"
    stack = "home-stack"
  }

  container_port = 8091
  node_port      = local.zwave_js_port

  local_config_path = "${local.home_stack_config}/zwave-js/"
  config_mount_path = "/usr/src/app/store/"
}

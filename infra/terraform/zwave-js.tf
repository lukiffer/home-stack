module "zwave_js" {
  source = "./modules/kubernetes-deployment"

  name            = "zwave-js"
  namespace       = resource.kubernetes_namespace.namespace.metadata[0].name
  container_image = "zwavejs/zwave-js-ui:latest"
  privileged      = true

  labels = {
    app   = "zwave-js"
    stack = "home-stack"
  }

  ports = [{
    name           = "zwave-js-http",
    container_port = 8091
    node_port      = local.zwave_js_http_node_port
    }, {
    name           = "zwave-js-websockets",
    container_port = 3000,
    node_port      = local.zwave_js_ws_node_port
  }]

  local_config_path = "${local.home_stack_config}/zwave-js/"
  config_mount_path = "/usr/src/app/store/"

  host_device_mounts = [
    "/dev/ttyUSB0",
  ]
}

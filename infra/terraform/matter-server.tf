module "matter_server" {
  source = "./modules/kubernetes-deployment"

  name            = "matter-server"
  namespace       = resource.kubernetes_namespace.namespace.metadata[0].name
  container_image = "ghcr.io/home-assistant-libs/python-matter-server:stable"

  # Matter discovery runs over IPv6 mDNS multicast, which never reaches the LAN from the pod network. Requires IPv6
  # to be enabled on the host.
  host_network = true

  labels = {
    app   = "matter-server"
    stack = "home-stack"
  }

  ports = [{
    name           = "matter-server-websocket",
    container_port = 5580,
    node_port      = local.matter_server_node_port,
  }]

  local_config_path = "${local.home_stack_config}/matter-server/"
  config_mount_path = "/data/"
}

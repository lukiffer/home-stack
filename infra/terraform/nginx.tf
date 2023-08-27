module "nginx" {
  source = "./modules/kubernetes-deployment"

  name            = "nginx"
  namespace       = resource.kubernetes_namespace.namespace.metadata[0].name
  container_image = "nginx:stable-alpine"

  labels = {
    app   = "nginx"
    stack = "home-stack"
  }

  ports = [{
    name           = "nginx-http",
    container_port = 80,
    node_port      = local.nginx_node_port,
  }]

  local_config_path = "${local.home_stack_config}/nginx/nginx.conf"
  config_mount_path = "/etc/nginx/conf.d/site.conf"
}

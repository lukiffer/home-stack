module "mariadb" {
  source = "./modules/kubernetes-deployment"

  name            = "mariadb"
  namespace       = resource.kubernetes_namespace.namespace.metadata[0].name
  container_image = "mariadb:latest"

  labels = {
    app   = "mariadb"
    stack = "home-stack"
  }

  env = [
    {
      name  = "MYSQL_USER",
      value = local.secrets.mariadb_username,
    },
    {
      name  = "MYSQL_PASSWORD",
      value = local.secrets.mariadb_password,
    },
    {
      name  = "MYSQL_ROOT_PASSWORD",
      value = local.secrets.mariadb_root_password,
    }
  ]

  container_port = 3306
  node_port      = local.mariadb_node_port

  local_config_path = "${local.home_stack_config}/mariadb/"
  config_mount_path = "/var/lib/mysql"
}

module "mariadb" {
  source = "./modules/kubernetes-deployment"

  name            = "mariadb"
  namespace       = resource.kubernetes_namespace.namespace.metadata[0].name
  container_image = "mariadb:latest"

  labels = {
    app   = "mariadb"
    stack = "home-stack"
  }

  env = {
    MYSQL_USER          = local.secrets.mariadb_username,
    MYSQL_PASSWORD      = local.secrets.mariadb_password
    MYSQL_ROOT_PASSWORD = local.secrets.mariadb_root_password,
    MYSQL_DATABASE      = "homeassistant",
  }

  container_port = 3306
  node_port      = local.mariadb_node_port

  local_config_path = "${local.home_stack_config}/mariadb/"
  config_mount_path = "/var/lib/mysql"
}

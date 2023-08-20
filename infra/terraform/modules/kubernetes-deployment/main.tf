terraform {
  required_version = ">= 1.5"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
  }
}

resource "kubernetes_deployment" "deployment" {

  metadata {
    name        = var.name
    namespace   = var.namespace
    annotations = var.annotations
    labels      = var.labels
  }

  spec {
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = var.labels
    }

    template {
      metadata {
        labels = var.labels
      }

      spec {
        hostname                         = var.name
        termination_grace_period_seconds = var.termination_grace_period_seconds

        container {
          name  = var.name
          image = var.container_image
          args  = var.container_args

          volume_mount {
            name       = "${var.name}-config-volume"
            mount_path = var.config_mount_path
          }

          port {
            container_port = var.container_port
          }

          dynamic "env" {
            for_each = coalesce(var.env, [])

            content {
              name  = env.value.name
              value = env.value.value
            }
          }

          dynamic "lifecycle" {
            for_each = var.post_start_command == null ? [] : [1]

            content {
              post_start {
                exec {
                  command = var.post_start_command
                }
              }
            }
          }
        }

        volume {
          name = "${var.name}-config-volume"

          # The gitRepo volume type has been deprecated.
          # The recommended path is to mount an EmptyDir into an InitContainer that clones the repository. This seems
          # a bit excessive for our immediate needs. We'll instead clone the repo in the bootstrap script, then mount
          # the host-local path to the container. If we need to ever scale to multiple nodes, we can adjust volume
          # strategy then.
          host_path {
            path = var.local_config_path
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "service" {
  depends_on = [
    kubernetes_deployment.deployment,
  ]

  metadata {
    name        = var.name
    namespace   = var.namespace
    annotations = var.annotations
    labels      = var.labels
  }

  spec {
    type     = "NodePort"
    selector = var.labels

    port {
      name        = "${var.name}-service-port"
      port        = var.container_port
      target_port = var.container_port
      node_port   = var.node_port
    }
  }
}

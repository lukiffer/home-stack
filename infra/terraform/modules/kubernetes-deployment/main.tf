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
          name              = var.name
          image             = var.container_image
          args              = var.container_args
          image_pull_policy = var.image_pull_policy

          volume_mount {
            name       = "${var.name}-config-volume"
            mount_path = var.config_mount_path
          }

          dynamic "volume_mount" {
            for_each = var.host_device_mounts
            content {
              name       = lower(replace(replace(volume_mount.value, "/^\\//", ""), "/", "-"))
              mount_path = volume_mount.value
            }
          }

          dynamic "port" {
            for_each = var.ports
            content {
              container_port = port.value.container_port
            }
          }

          dynamic "security_context" {
            for_each = var.privileged == true ? [1] : []
            content {
              privileged = true
            }
          }

          dynamic "env" {
            for_each = nonsensitive(toset(keys(var.env)))

            content {
              name  = env.key
              value = var.env[env.key]
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

        dynamic "volume" {
          for_each = var.host_device_mounts
          content {
            name = lower(replace(replace(volume.value, "/^\\//", ""), "/", "-"))
            host_path {
              path = volume.value
            }
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

    dynamic "port" {
      for_each = var.ports
      content {
        name        = port.value.name
        port        = port.value.container_port
        target_port = port.value.container_port
        node_port   = port.value.node_port
      }
    }
  }
}

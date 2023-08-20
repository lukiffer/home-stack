variable "name" {
  description = "The name of the deployment. Must be unique within the cluster or namespace, and cannot be updated."
  type        = string
}

variable "namespace" {
  description = "The namespace within which the name of the deployment must be unique."
  type        = string
  default     = null
}

variable "annotations" {
  description = "An unstructured key value map stored with the deployment that may be used to store arbitrary metadata."
  type        = map(string)
  default     = null
}

variable "labels" {
  description = "A map of string keys and values that can be used to organize and categorize (scope and select) the deployment."
  type        = map(string)
  default     = {}
}

variable "termination_grace_period_seconds" {
  description = "The duration in seconds the pod needs to terminate gracefully. Must be a non-negative integer."
  type        = number
  default     = 120
}

variable "container_image" {
  description = "The name of the container image to be run."
  type        = string
}

variable "container_args" {
  description = "A list of string arguments to be passed to the container."
  type        = list(string)
  default     = []
}

variable "container_port" {
  description = "The port exposed by the container that will be proxied by the service."
  type        = number
}

variable "node_port" {
  description = "The port exposed by the node to the ingress."
  type        = number
}

variable "env" {
  description = "A map of environment variables."
  sensitive   = true
  type        = map(string)
  default     = {}
}

variable "config_mount_path" {
  description = "The path within the container where the configuration volume will be mounted."
  type        = string
  default     = "/config/"
}

variable "local_config_path" {
  description = "The node-local path where the config volume will be stored."
  type        = string
}

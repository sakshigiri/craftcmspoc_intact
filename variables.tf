variable "region" {
  description = "AWS region"
  default     = "ca-central-1"
}

variable "cluster_name" {
  description = "ECS Cluster name"
  default     = "craftcms-cluster"
}

variable "service_name" {
  description = "ECS Service name"
  default     = "craftcms-service"
}

variable "task_cpu" {
  description = "CPU units for the task"
  default     = 256
}

variable "task_memory" {
  description = "Memory for the task"
  default     = 512
}

variable "container_port" {
  description = "Port for the Craft CMS container"
  default     = 80
}

variable "environment_name" {
  description = "Name of the azd environment"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
}

variable "max_replicas" {
  description = "Maximum number of container app replicas"
  type        = number
  default     = 10
}

variable "http_concurrency_threshold" {
  description = "Number of concurrent HTTP requests before KEDA scales out (low value for demo)"
  type        = string
  default     = "10"
}

variable "project_id" {
  description = "Google Cloud project ID where the GKE cluster will be created."
  type        = string
}

variable "region" {
  description = "Google Cloud region for the cluster. Seoul is asia-northeast3."
  type        = string
  default     = "asia-northeast3"
}

variable "zone" {
  description = "Zone for this zonal cluster."
  type        = string
  default     = "asia-northeast3-a"
}

variable "cluster_name" {
  description = "Name of the GKE cluster."
  type        = string
  default     = "fastcampers-gke"
}

variable "machine_type" {
  description = "Machine type used by each worker node."
  type        = string
  default     = "e2-micro"
}

variable "worker_count" {
  description = "Number of worker nodes in the node pool."
  type        = number
  default     = 2
}

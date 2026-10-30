output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.primary.name
}

output "cluster_location" {
  description = "Zone containing the zonal cluster control plane and worker nodes."
  value       = google_container_cluster.primary.location
}

output "get_credentials_command" {
  description = "Run this command to configure kubectl access."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${google_container_cluster.primary.location} --project ${var.project_id}"
}

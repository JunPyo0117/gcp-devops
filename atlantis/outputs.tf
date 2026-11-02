output "atlantis_ip" {
  description = "Static external IP to add as the domain's DNS A record."
  value       = google_compute_address.atlantis.address
}

output "atlantis_url" {
  description = "Atlantis HTTPS URL. DNS must resolve to atlantis_ip."
  value       = "https://${var.atlantis_domain}"
}

output "iap_ssh_command" {
  description = "SSH to the Atlantis VM through Identity-Aware Proxy."
  value       = "gcloud compute ssh ${google_compute_instance.atlantis.name} --zone ${var.zone} --project ${var.project_id} --tunnel-through-iap"
}

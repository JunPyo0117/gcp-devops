output "atlantis_ip" {
  description = "Static external IP to map to the Atlantis DNS A record."
  value       = google_compute_address.atlantis.address
}

output "atlantis_url" {
  description = "HTTPS URL for the Atlantis server."
  value       = "https://${local.atlantis_domain}"
}

output "github_webhook_url" {
  description = "HTTPS URL to use in the GitHub App webhook settings with SSL verification enabled."
  value       = "https://${local.atlantis_domain}/events"
}

output "iap_ssh_command" {
  description = "SSH to the Atlantis VM through Identity-Aware Proxy."
  value       = "gcloud compute ssh ${google_compute_instance.atlantis.name} --zone ${var.zone} --project ${var.project_id} --tunnel-through-iap"
}

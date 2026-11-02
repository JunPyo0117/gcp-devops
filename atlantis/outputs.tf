output "atlantis_ip" {
  description = "Static external IP for the test-only HTTP endpoint."
  value       = google_compute_address.atlantis.address
}

output "atlantis_url" {
  description = "HTTP URL for this test-only Atlantis server."
  value       = "http://${google_compute_address.atlantis.address}:4141"
}

output "github_webhook_url" {
  description = "Use this HTTP URL in the GitHub App webhook settings and disable SSL verification for this test."
  value       = "http://${google_compute_address.atlantis.address}:4141/events"
}

output "iap_ssh_command" {
  description = "SSH to the Atlantis VM through Identity-Aware Proxy."
  value       = "gcloud compute ssh ${google_compute_instance.atlantis.name} --zone ${var.zone} --project ${var.project_id} --tunnel-through-iap"
}

variable "project_id" {
  description = "Google Cloud project ID where GKE and the Atlantis VM will run."
  type        = string
}

variable "region" {
  description = "Region for the Atlantis VM and static IP."
  type        = string
  default     = "asia-northeast3"
}

variable "zone" {
  description = "Zone for the Atlantis VM."
  type        = string
  default     = "asia-northeast3-a"
}

variable "name" {
  description = "Prefix used for Atlantis resources and secret names."
  type        = string
  default     = "gcp-devops-atlantis"
}

variable "state_bucket" {
  description = "Existing GCS bucket used by both Terraform roots for remote state."
  type        = string
}

variable "atlantis_domain" {
  description = "DNS name that will point to the Atlantis static IP and serve HTTPS."
  type        = string
}

variable "github_repository" {
  description = "Only this GitHub repository is allowed to use this Atlantis server."
  type        = string
  default     = "JunPyo0117/gcp-devops"
}

variable "github_admin_user" {
  description = "GitHub username permitted to run Atlantis apply/import/state modification commands."
  type        = string
  default     = "JunPyo0117"
}

variable "github_app_id" {
  description = "ID of the GitHub App installed on the repository."
  type        = string
}

variable "github_app_installation_id" {
  description = "Installation ID of the GitHub App for the repository."
  type        = string
}

variable "github_api_user" {
  description = "GitHub username used for Atlantis API attribution (normally the GitHub App bot login)."
  type        = string
  default     = "atlantis[bot]"
}

variable "github_app_key_secret_id" {
  description = "Existing Secret Manager secret containing the GitHub App PEM private key."
  type        = string
  default     = "gcp-devops-atlantis-github-app-key"
}

variable "github_webhook_secret_id" {
  description = "Existing Secret Manager secret containing the GitHub App webhook secret."
  type        = string
  default     = "gcp-devops-atlantis-webhook-secret"
}

variable "atlantis_ui_password_secret_id" {
  description = "Existing Secret Manager secret containing the password for the protected Atlantis UI."
  type        = string
  default     = "gcp-devops-atlantis-ui-password"
}

variable "machine_type" {
  description = "Compute Engine machine type for Atlantis. e2-small is a low-cost starter size."
  type        = string
  default     = "e2-small"
}

variable "atlantis_version" {
  description = "Pinned Atlantis container image version."
  type        = string
  default     = "v0.49.0"
}

variable "terraform_version" {
  description = "Default Terraform version downloaded by Atlantis when a repo does not pin one."
  type        = string
  default     = "1.16.6"
}

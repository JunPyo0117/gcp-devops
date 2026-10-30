terraform {
  required_version = ">= 1.5.0"

  # Atlantis and local Terraform runs must share state through GCS.
  # Configure bucket and prefix with TF_CLI_ARGS_init or backend config.
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  secret_ids = {
    github_app_key = var.github_app_key_secret_id
    webhook        = var.github_webhook_secret_id
    ui_password    = var.atlantis_ui_password_secret_id
  }
}

resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "iap.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "atlantis" {
  name                    = "${var.name}-network"
  auto_create_subnetworks = false

  depends_on = [google_project_service.services]
}

resource "google_compute_subnetwork" "atlantis" {
  name          = "${var.name}-subnet"
  region        = var.region
  network       = google_compute_network.atlantis.id
  ip_cidr_range = "10.40.0.0/24"
}

resource "google_compute_address" "atlantis" {
  name         = "${var.name}-ip"
  region       = var.region
  address_type = "EXTERNAL"

  depends_on = [google_project_service.services]
}

resource "google_compute_firewall" "https" {
  name          = "${var.name}-https"
  network       = google_compute_network.atlantis.name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "google_compute_firewall" "iap_ssh" {
  name          = "${var.name}-iap-ssh"
  network       = google_compute_network.atlantis.name
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_service_account" "atlantis" {
  account_id   = "atlantis-server"
  display_name = "Atlantis Terraform runner"

  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "atlantis_roles" {
  for_each = toset([
    "roles/container.admin",
    "roles/compute.networkAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/iam.serviceAccountUser",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.atlantis.email}"
}

resource "google_storage_bucket_iam_member" "state_access" {
  bucket = var.state_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.atlantis.email}"
}

resource "google_secret_manager_secret_iam_member" "secret_access" {
  for_each = local.secret_ids

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.atlantis.email}"

  depends_on = [google_project_service.services]
}

resource "google_compute_instance" "atlantis" {
  name                      = var.name
  machine_type              = var.machine_type
  zone                      = var.zone
  tags                      = [var.name]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
      size  = 30
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.atlantis.id
    access_config {
      nat_ip = google_compute_address.atlantis.address
    }
  }

  service_account {
    email  = google_service_account.atlantis.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = templatefile("${path.module}/startup.sh.tftpl", {
    project_id                     = var.project_id
    atlantis_domain                = var.atlantis_domain
    github_repository              = var.github_repository
    github_admin_user              = var.github_admin_user
    github_api_user                = var.github_api_user
    github_app_id                  = var.github_app_id
    github_app_installation_id     = var.github_app_installation_id
    state_bucket                   = var.state_bucket
    github_app_key_secret_id       = var.github_app_key_secret_id
    github_webhook_secret_id       = var.github_webhook_secret_id
    atlantis_ui_password_secret_id = var.atlantis_ui_password_secret_id
    atlantis_version               = var.atlantis_version
    terraform_version              = var.terraform_version
    machine_type                   = var.machine_type
    repo_config = templatefile("${path.module}/repos.yaml.tftpl", {
      github_repository = var.github_repository
    })
    auth_script = templatefile("${path.module}/authorize.sh.tftpl", {
      github_admin_user = var.github_admin_user
    })
  })

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  depends_on = [
    google_project_service.services,
    google_project_iam_member.atlantis_roles,
    google_secret_manager_secret_iam_member.secret_access,
    google_storage_bucket_iam_member.state_access,
  ]
}

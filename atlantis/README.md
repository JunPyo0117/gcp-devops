# Atlantis server on GCP

This Terraform root provisions a small Debian Compute Engine VM in Seoul with a reserved external IP, Caddy-managed HTTPS, OS Login over IAP (no public SSH), a dedicated runtime service account, and Secret Manager access. Atlantis is pinned to `v0.49.0`; its default Terraform version is pinned in variables. Caddy serves the webhook endpoint over HTTPS and protects the browser UI with Basic Auth.

The Atlantis VM's service account can create GKE clusters, networks, enable project APIs, and read/write Terraform state. Treat the server and this public repository as privileged infrastructure. The GitHub App is restricted to the repository, fork PR execution is disabled, and server-side policy restricts apply/import/state changes to the configured admin user. Repo-defined workflows are disabled; only the fixed workflows in the server-side config are accepted.

## Prerequisites

- A GCP project with billing enabled and `gcloud`, Terraform 1.5+, and GitHub admin access.
- A globally unique GCS bucket already created for remote state, with object versioning enabled.
- A domain name you control. The VM gets a static IP; create its DNS A record after the first apply.
- A GitHub App installed only on `JunPyo0117/gcp-devops` (or the repository configured in `github_repository`).
- Your Google account needs permission to create the resources. To SSH through IAP, grant your account `roles/iap.tunnelResourceAccessor` and `roles/compute.osLogin` (plus `roles/compute.viewer` if needed).

## Prepare GitHub and secrets

Create a GitHub App and set its webhook URL to `https://YOUR_DOMAIN/events`. Enable a webhook secret. Grant the app the Atlantis GitHub permissions: Administration read-only, Checks read/write, Commit statuses read/write, Contents read/write, Issues read/write, Metadata read-only, Pull requests read/write, Webhooks read/write, Members read-only, and Actions read-only. Install it only on this repository and record its App ID, Installation ID, private key PEM, and webhook secret.

Enable Secret Manager and create the three secrets before applying this Terraform root. Create a strong, unique UI password for Basic Auth. Add actual secret versions; Terraform never handles secret values:

```sh
gcloud services enable secretmanager.googleapis.com --project=YOUR_PROJECT_ID
gcloud secrets create gcp-devops-atlantis-github-app-key --replication-policy=automatic --project=YOUR_PROJECT_ID
gcloud secrets create gcp-devops-atlantis-webhook-secret --replication-policy=automatic --project=YOUR_PROJECT_ID
gcloud secrets create gcp-devops-atlantis-ui-password --replication-policy=automatic --project=YOUR_PROJECT_ID
gcloud secrets versions add gcp-devops-atlantis-github-app-key --data-file=/path/to/private-key.pem --project=YOUR_PROJECT_ID
printf '%s' 'YOUR_WEBHOOK_SECRET' | gcloud secrets versions add gcp-devops-atlantis-webhook-secret --data-file=- --project=YOUR_PROJECT_ID
printf '%s' 'YOUR_LONG_RANDOM_UI_PASSWORD' | gcloud secrets versions add gcp-devops-atlantis-ui-password --data-file=- --project=YOUR_PROJECT_ID
```

## Deploy

```sh
cp terraform.tfvars.example terraform.tfvars
# Set project_id, state_bucket, atlantis_domain, github_app_id, and github_app_installation_id.
# Set github_api_user to the GitHub App bot login (usually <app-slug>[bot]).
terraform init -backend-config="bucket=YOUR_UNIQUE_STATE_BUCKET" -backend-config="prefix=atlantis/terraform/state"
terraform plan
terraform apply
```

Create an A record for `atlantis_domain` pointing to the `atlantis_ip` output. Caddy will request and renew a public TLS certificate; ports 80 and 443 must be reachable. The VM startup script installs Docker and Google Cloud CLI, reads secrets at boot, then starts Atlantis and Caddy.

In GitHub App settings, confirm the webhook endpoint and install scope. Open `https://YOUR_DOMAIN` and sign in with username `admin` and the UI password stored in Secret Manager. Only the configured `github_admin_user` can issue apply/import/state modification commands.

## State and PR behavior

The server-side Atlantis config allows only the fixed GKE workflow and rejects repository-defined workflows. This VM's Terraform root is intentionally operated locally, not through the Atlantis server it provisions. Its state uses the `atlantis/terraform/state` prefix; the GKE root uses `gke/terraform/state`. The Atlantis service account receives object access to the shared bucket for GKE plans and applies.

Do not enable `--allow-fork-prs` for this public repository. Limit write access and protect `main`; Terraform plans execute code from same-repository PRs with the Atlantis service account's GCP permissions. Applies remain explicit via `atlantis apply` and are limited to the configured admin.

To inspect startup logs, use the `iap_ssh_command` output and then `sudo journalctl -t atlantis-startup` or `docker logs atlantis` / `docker logs caddy`.

To remove the VM and network, run `terraform destroy` from this directory. This does not delete the shared state bucket or Secret Manager secrets. The reserved IP is deleted with the Terraform resources.

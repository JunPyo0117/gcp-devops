# Atlantis server on GCP

This Terraform root provisions a small Debian Compute Engine VM in Seoul with a reserved external IP, Caddy-managed HTTPS, OS Login over IAP (no public SSH), a dedicated runtime service account, and Secret Manager access. Atlantis is pinned to `v0.49.0`; its default Terraform version is pinned in variables. Caddy protects the browser UI with Basic Auth and forwards the GitHub webhook endpoint to Atlantis.

The Atlantis VM's service account can create GKE clusters, networks, enable project APIs, and read/write Terraform state. Treat the server and this public repository as privileged infrastructure. The GitHub App is restricted to the repository and fork PR execution is disabled. This personal-account lab configuration allows `plan` only because Atlantis team authorization requires GitHub organization teams; `apply`, `import`, and state-changing commands are disabled. Repo-defined workflows are disabled; only the fixed workflows in the server-side config are accepted.

## Prerequisites

- A GCP project with billing enabled and `gcloud`, Terraform 1.5+, and GitHub admin access.
- A globally unique GCS bucket already created for remote state, with object versioning enabled.
- No domain is required for a lab run: the default URL uses the public wildcard DNS service `nip.io`. You can provide an owned domain later.
- A GitHub App installed only on `JunPyo0117/gcp-devops` (or the repository configured in `github_repository`).
- Your Google account needs permission to create the resources. To SSH through IAP, grant your account `roles/iap.tunnelResourceAccessor` and `roles/compute.osLogin` (plus `roles/compute.viewer` if needed).

## Prepare GitHub and secrets

Create a GitHub App. Use `https://github.com/JunPyo0117/gcp-devops` as its homepage URL, leave OAuth redirect URIs blank, and do not request user authorization or device flow. Keep its webhook inactive until Terraform creates the VM and HTTPS is ready. Grant the app the Atlantis GitHub permissions: Administration read-only, Checks read/write, Commit statuses read/write, Contents read/write, Issues read/write, Metadata read-only, Pull requests read/write, Webhooks read/write, Members read-only, and Actions read-only. Install it only on this repository and record its App ID, Installation ID, private key PEM, and webhook secret.

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
# Set project_id, state_bucket, github_app_id, and github_app_installation_id.
# atlantis_domain can stay empty to use nip.io, or contain a domain you own.
terraform init -backend-config="bucket=YOUR_UNIQUE_STATE_BUCKET" -backend-config="prefix=atlantis/terraform/state"
terraform plan
terraform apply
```

After apply, the default `atlantis_url` is based on the static IP and `nip.io`; no DNS record is needed. If you set your own domain, create an A record to the `atlantis_ip` output. Caddy will obtain and renew the public TLS certificate; ports 80 and 443 must be reachable. Wait for `atlantis_url` to load, then activate the GitHub App webhook using the `github_webhook_url` output with SSL verification enabled. Select Pull requests, Issue comments, Pull request reviews, and Push events.

The default `nip.io` name depends on a third-party wildcard DNS service and is for learning only. Use a domain you control for a durable deployment.

Open the `atlantis_url` output and sign in with username `admin` and the UI password stored in Secret Manager. For `apply` permissions restricted to GitHub teams, use a GitHub Organization and configure Atlantis team authorization.

## State and PR behavior

The server-side Atlantis config allows only the fixed GKE workflow and rejects repository-defined workflows. This VM's Terraform root is intentionally operated locally, not through the Atlantis server it provisions. Its state uses the `atlantis/terraform/state` prefix; the GKE root uses `gke/terraform/state`. The Atlantis service account receives object access to the shared bucket for GKE plans and applies.

Do not enable `--allow-fork-prs` for this public repository. Limit write access and protect `main`; Terraform plans execute code from same-repository PRs with the Atlantis service account's GCP permissions. Applies remain explicit via `atlantis apply` and are limited to the configured admin.

To inspect startup logs, use the `iap_ssh_command` output and then `sudo journalctl -t atlantis-startup` or `docker logs atlantis`.

To remove the VM and network, run `terraform destroy` from this directory. This does not delete the shared state bucket or Secret Manager secrets. The reserved IP is deleted with the Terraform resources.

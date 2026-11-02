# Atlantis webhook gateway contract

The public endpoint remains `POST /events`. Caddy forwards that route to this
gateway; Atlantis itself is reachable only on the private Docker network.

## Request

The gateway accepts GitHub JSON webhook deliveries with these headers:

- `X-Hub-Signature-256`: HMAC-SHA256 signature over the exact request body.
- `X-GitHub-Event`: GitHub event name.
- `X-GitHub-Delivery`: stable delivery ID used to deduplicate retries.
- `Content-Length`: payload length, limited to 2 MiB.

The signature is checked with the webhook secret mounted from Secret Manager.
Only the configured `github_admin_user` and exact configured repository are
trusted. The gateway forwards newly created PR comments and supported
pull-request lifecycle events only when the sender is that user. Pull requests
must have both head and base in the configured repository, so fork PRs are
ignored.

## Responses

- `2xx`: the authorized event was accepted by Atlantis, or a signed but
  unsupported/unauthorized event was safely ignored (`202`).
- `400`: required GitHub headers or valid JSON are missing.
- `401`: the signature is missing or invalid.
- `413`: the body exceeds 2 MiB.
- `502`: Atlantis could not be reached; GitHub may retry the delivery.

Successful and intentionally ignored deliveries are deduplicated by
`X-GitHub-Delivery` in the gateway process for six hours. Atlantis verifies the
same signature again after forwarding. The gateway does not log request bodies,
signatures, or secret values.

#!/usr/bin/env python3
"""Verify GitHub webhook signatures and forward only trusted user events."""

from collections import OrderedDict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
import hashlib
import hmac
import json
import logging
import os
import threading
import time


LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = int(os.environ.get("PORT", "8080"))
BACKEND_URL = os.environ.get("ATLANTIS_EVENTS_URL", "http://atlantis:4141/events")
ALLOWED_USER = os.environ["GITHUB_ALLOWED_USER"].casefold()
ALLOWED_REPOSITORY = os.environ["GITHUB_REPOSITORY"].casefold()
SECRET_PATH = os.environ.get(
    "GITHUB_WEBHOOK_SECRET_FILE", "/run/secrets/webhook-secret"
)
MAX_BODY_BYTES = 2 * 1024 * 1024
CACHE_TTL_SECONDS = 6 * 60 * 60
CACHE_LIMIT = 2048
FORWARD_EVENTS = {"issue_comment", "pull_request"}
PULL_REQUEST_ACTIONS = {
    "opened",
    "reopened",
    "synchronize",
    "ready_for_review",
    "closed",
}

with open(SECRET_PATH, "rb") as secret_file:
    WEBHOOK_SECRET = secret_file.read().rstrip(b"\r\n")
if not WEBHOOK_SECRET:
    raise RuntimeError("GitHub webhook secret is empty")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)

_cache_lock = threading.Lock()
_delivery_cache = OrderedDict()


def _response_body(status, message):
    return status, json.dumps({"status": message}).encode("utf-8")


def _cached_response(delivery_id):
    now = time.monotonic()
    with _cache_lock:
        expired = [key for key, (expiry, _, _) in _delivery_cache.items() if expiry <= now]
        for key in expired:
            _delivery_cache.pop(key, None)
        cached = _delivery_cache.get(delivery_id)
        if cached is None:
            return None
        expiry, status, body = cached
        _delivery_cache.move_to_end(delivery_id)
        return status, body


def _remember_response(delivery_id, status, body):
    with _cache_lock:
        _delivery_cache[delivery_id] = (
            time.monotonic() + CACHE_TTL_SECONDS,
            status,
            body,
        )
        _delivery_cache.move_to_end(delivery_id)
        while len(_delivery_cache) > CACHE_LIMIT:
            _delivery_cache.popitem(last=False)


def _is_allowed_event(event, payload):
    sender = payload.get("sender") or {}
    login = sender.get("login", "")
    if not isinstance(login, str) or login.casefold() != ALLOWED_USER:
        return False, "sender_not_allowed"

    repository = (payload.get("repository") or {}).get("full_name", "")
    if not isinstance(repository, str) or repository.casefold() != ALLOWED_REPOSITORY:
        return False, "repository_not_allowed"

    if event == "issue_comment":
        issue = payload.get("issue") or {}
        if payload.get("action") != "created" or not issue.get("pull_request"):
            return False, "not_a_new_pull_request_comment"
        return True, "authorized"

    if event == "pull_request":
        if payload.get("action") not in PULL_REQUEST_ACTIONS:
            return False, "pull_request_action_ignored"
        pull = payload.get("pull_request") or {}
        head_repo = ((pull.get("head") or {}).get("repo") or {}).get("full_name", "")
        base_repo = ((pull.get("base") or {}).get("repo") or {}).get("full_name", "")
        if (
            not isinstance(head_repo, str)
            or not isinstance(base_repo, str)
            or head_repo.casefold() != ALLOWED_REPOSITORY
            or base_repo.casefold() != ALLOWED_REPOSITORY
        ):
            return False, "fork_pull_request_ignored"
        return True, "authorized"

    return False, "event_not_supported"


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        logging.info("%s - %s", self.client_address[0], fmt % args)

    def _send(self, status, body, content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path != "/events":
            self._send(*_response_body(404, "not_found"))
            return

        try:
            content_length = int(self.headers.get("Content-Length", "-1"))
        except ValueError:
            content_length = -1
        if content_length < 0:
            self._send(*_response_body(400, "invalid_content_length"))
            return
        if content_length > MAX_BODY_BYTES:
            self.close_connection = True
            self._send(*_response_body(413, "payload_too_large"))
            return

        body = self.rfile.read(content_length)
        signature = self.headers.get("X-Hub-Signature-256", "")
        expected_signature = (
            "sha256=" + hmac.new(WEBHOOK_SECRET, body, hashlib.sha256).hexdigest()
        ).encode("ascii")
        try:
            provided_signature = signature.encode("ascii")
        except UnicodeEncodeError:
            provided_signature = b""
        if not hmac.compare_digest(provided_signature, expected_signature):
            logging.warning("rejected webhook with invalid signature")
            self._send(*_response_body(401, "invalid_signature"))
            return

        event = self.headers.get("X-GitHub-Event", "")
        delivery_id = self.headers.get("X-GitHub-Delivery", "")
        if not event or not delivery_id:
            self._send(*_response_body(400, "missing_github_headers"))
            return

        cached = _cached_response(delivery_id)
        if cached is not None:
            self._send(cached[0], cached[1])
            return

        try:
            payload = json.loads(body)
        except (UnicodeDecodeError, json.JSONDecodeError):
            self._send(*_response_body(400, "invalid_json"))
            return
        if not isinstance(payload, dict):
            self._send(*_response_body(400, "invalid_payload"))
            return

        if event not in FORWARD_EVENTS:
            response = _response_body(202, "event_ignored")
            _remember_response(delivery_id, *response)
            self._send(*response)
            return

        allowed, reason = _is_allowed_event(event, payload)
        if not allowed:
            logging.info("ignored delivery %s: %s", delivery_id, reason)
            response = _response_body(202, reason)
            _remember_response(delivery_id, *response)
            self._send(*response)
            return

        forward_headers = {
            "Content-Type": self.headers.get("Content-Type", "application/json"),
            "User-Agent": self.headers.get("User-Agent", "GitHub-Hookshot"),
            "X-GitHub-Event": event,
            "X-GitHub-Delivery": delivery_id,
            "X-Hub-Signature-256": signature,
        }
        request = Request(
            BACKEND_URL,
            data=body,
            headers=forward_headers,
            method="POST",
        )
        try:
            with urlopen(request, timeout=8) as response:
                status = response.status
                response_body = response.read(MAX_BODY_BYTES)
                content_type = response.headers.get("Content-Type", "application/json")
        except HTTPError as error:
            status = error.code
            response_body = error.read(MAX_BODY_BYTES)
            content_type = error.headers.get("Content-Type", "application/json")
        except (URLError, TimeoutError, OSError) as error:
            logging.error("Atlantis forwarding failed for delivery %s: %s", delivery_id, error)
            self._send(*_response_body(502, "atlantis_unavailable"))
            return

        if 200 <= status < 300:
            _remember_response(delivery_id, status, response_body)
        self._send(status, response_body, content_type)


if __name__ == "__main__":
    server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Handler)
    server.daemon_threads = True
    logging.info("webhook gateway listening on %s:%d", LISTEN_HOST, LISTEN_PORT)
    server.serve_forever()

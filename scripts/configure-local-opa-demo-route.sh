#!/usr/bin/env bash

set -euo pipefail

CONTEXT="${CONTEXT:-kind-don-local}"
ADMIN_PORT="${ADMIN_PORT:-19180}"
NAMESPACE="${NAMESPACE:-tn-don-api}"
APISIX_SECRET="${APISIX_SECRET:-don-api-apisix}"
APISIX_ADMIN_SERVICE="${APISIX_ADMIN_SERVICE:-don-api-apisix-admin}"
OPA_SERVICE_URL="${OPA_SERVICE_URL:-http://don-api-opa:8181}"
UPSTREAM_HOST="${UPSTREAM_HOST:-don-api-opa.tn-don-api.svc.cluster.local:8181}"

kubectl config use-context "$CONTEXT" >/dev/null

kubectl rollout status -n "$NAMESPACE" deploy/don-api-apisix --timeout=180s >/dev/null
kubectl rollout status -n "$NAMESPACE" deploy/don-api-opa --timeout=180s >/dev/null

admin_key="$(
  kubectl get secret "$APISIX_SECRET" -n "$NAMESPACE" -o json \
    | jq -r '.data.admin | @base64d'
)"

kubectl port-forward -n "$NAMESPACE" "svc/$APISIX_ADMIN_SERVICE" "$ADMIN_PORT:9180" >/tmp/don-apisix-admin-port-forward.log 2>&1 &
port_forward_pid=$!
trap 'kill "$port_forward_pid" >/dev/null 2>&1 || true' EXIT

for _ in $(seq 1 20); do
  if curl -fsS "http://127.0.0.1:${ADMIN_PORT}/apisix/admin/routes" -H "X-API-KEY: ${admin_key}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "http://127.0.0.1:${ADMIN_PORT}/apisix/admin/routes/opa-local-demo" \
  -H "X-API-KEY: ${admin_key}" \
  -H "Content-Type: application/json" \
  -X PUT \
  -d @- <<JSON
{
  "name": "opa-local-demo",
  "uri": "/opa-demo/*",
  "labels": {
    "required_scopes": "apis:read"
  },
  "plugins": {
    "opa": {
      "host": "${OPA_SERVICE_URL}",
      "policy": "apisix/authz/result",
      "timeout": 3000,
      "with_route": true
    },
    "proxy-rewrite": {
      "uri": "/health"
    }
  },
  "upstream": {
    "type": "roundrobin",
    "scheme": "http",
    "nodes": {
      "${UPSTREAM_HOST}": 1
    }
  }
}
JSON

echo "OPA demo route configured at http://127.0.0.1:9080/opa-demo/"

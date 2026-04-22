#!/usr/bin/env bash

set -euo pipefail

CONTEXT="${CONTEXT:-kind-don-local}"
ADMIN_PORT="${ADMIN_PORT:-19180}"
NAMESPACE="${NAMESPACE:-tn-don-api}"
APISIX_SECRET="${APISIX_SECRET:-don-api-apisix}"
APISIX_ADMIN_SERVICE="${APISIX_ADMIN_SERVICE:-don-api-apisix-admin}"

kubectl config use-context "$CONTEXT" >/dev/null

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
  -X DELETE

echo "OPA demo route removed"

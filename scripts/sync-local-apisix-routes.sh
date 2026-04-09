#!/usr/bin/env bash

set -euo pipefail

CONTEXT="${CONTEXT:-kind-don-local}"
ADMIN_PORT="${ADMIN_PORT:-19180}"
NAMESPACE="${NAMESPACE:-tn-don-api}"
APISIX_SECRET="${APISIX_SECRET:-don-api-apisix}"
APISIX_ADMIN_SERVICE="${APISIX_ADMIN_SERVICE:-don-api-apisix-admin}"
APISIX_HELMRELEASE="${APISIX_HELMRELEASE:-don-api-apisix}"
ROUTES_FILE="${ROUTES_FILE:-apps/api/base/apisix/routes/adc.yaml}"

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

kubectl config use-context "$CONTEXT" >/dev/null

kubectl wait -n "$NAMESPACE" --for=condition=ready "helmrelease/${APISIX_HELMRELEASE}" --timeout=300s >/dev/null 2>&1 || true

for _ in $(seq 1 60); do
  if kubectl get secret "$APISIX_SECRET" -n "$NAMESPACE" >/dev/null 2>&1 \
    && kubectl get svc "$APISIX_ADMIN_SERVICE" -n "$NAMESPACE" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! kubectl get secret "$APISIX_SECRET" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "APISIX admin secret $APISIX_SECRET is nog niet beschikbaar in namespace $NAMESPACE" >&2
  exit 1
fi

if ! kubectl get svc "$APISIX_ADMIN_SERVICE" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "APISIX admin service $APISIX_ADMIN_SERVICE is nog niet beschikbaar in namespace $NAMESPACE" >&2
  exit 1
fi

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

config_json="$(
  ruby -rjson -ryaml -e 'puts JSON.generate(YAML.safe_load(File.read(ARGV[0]), aliases: true))' "$ROUTES_FILE"
)"

printf '%s\n' "$config_json" | jq -c '.services[]' | while read -r service; do
  service_name="$(printf '%s' "$service" | jq -r '.name')"
  upstream_json="$(printf '%s' "$service" | jq '.upstream + {type: (.upstream.type // "roundrobin")}')"

  printf '%s' "$service" | jq -c '.routes[]' | while read -r route; do
    route_name="$(printf '%s' "$route" | jq -r '.name')"
    route_desc="$(printf '%s' "$route" | jq -r '.description // ""')"
    methods_json="$(printf '%s' "$route" | jq '.methods // []')"
    uris_json="$(printf '%s' "$route" | jq '.uris // []')"
    plugins_json="$(printf '%s' "$route" | jq '.plugins // {}')"
    labels_json="$(printf '%s' "$route" | jq '.labels // {}')"

    route_id="$(slugify "${service_name}-${route_name}")"

    payload="$(
      jq -n \
        --arg name "$route_name" \
        --arg desc "$route_desc" \
        --argjson methods "$methods_json" \
        --argjson uris "$uris_json" \
        --argjson plugins "$plugins_json" \
        --argjson labels "$labels_json" \
        --argjson upstream "$upstream_json" \
        '{
          name: $name,
          methods: $methods,
          uris: $uris,
          plugins: $plugins,
          labels: $labels,
          upstream: $upstream
        } + (if $desc != "" then {desc: $desc} else {} end)'
    )"

    curl -fsS "http://127.0.0.1:${ADMIN_PORT}/apisix/admin/routes/${route_id}" \
      -H "X-API-KEY: ${admin_key}" \
      -H "Content-Type: application/json" \
      -X PUT \
      -d "$payload" >/dev/null

    echo "Synced APISIX route ${route_id}"
  done
done

echo "APISIX routes synced from ${ROUTES_FILE}"

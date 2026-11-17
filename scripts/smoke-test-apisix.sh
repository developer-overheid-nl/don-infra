#!/usr/bin/env bash
# Smoke test for the DON API gateway after the move to the APISIX gateway of
# Digilab (namespace apisix). Run it after the merge.
#
#   KUBECONFIG=<digikluster> scripts/smoke-test-apisix.sh test|prod
#
# Optional: DON_API_KEY=<key> also tests an authenticated request (OPA and
# limit-count). Without it, that check is skipped.
set -uo pipefail

env=${1:?usage: $0 test|prod}
ns="tn-don-api-$env"
gw_ns=apisix
gw="apisix-$env"
case $env in
  test) host=api.don.projects.digilab.network ;;
  prod) host=api.developer.overheid.nl ;;
  *) echo "unknown env: $env" >&2; exit 2 ;;
esac
base="https://$host"
expected_rev=${EXPECTED_REVISION:-$(git rev-parse origin/main 2>/dev/null || echo)}

fails=0
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; fails=$((fails + 1)); }
skip() { printf '  \033[33mSKIP\033[0m %s\n' "$*"; }

echo "== Flux"
rev=$(kubectl -n "$ns" get kustomization tn-don-api -o jsonpath='{.status.lastAppliedRevision}')
ready=$(kubectl -n "$ns" get kustomization tn-don-api -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
[[ $ready == True ]] && ok "Kustomization tn-don-api is Ready ($rev)" || fail "Kustomization tn-don-api is not Ready ($rev)"
if [[ -n $expected_rev ]]; then
  [[ $rev == *"$expected_rev"* ]] && ok "applied revision is origin/main" \
    || fail "applied revision $rev is not origin/main $expected_rev (run: flux -n $ns reconcile ks tn-don-api --with-source)"
fi

echo "== APISIX objects in $ns"
want_class="apisix-don-$env"
for kind in apisixroute apisixupstream apisixpluginconfig; do
  for name in $(kubectl -n "$ns" get "$kind" -o name); do
    class=$(kubectl -n "$ns" get "$name" -o jsonpath='{.spec.ingressClassName}')
    gen=$(kubectl -n "$ns" get "$name" -o jsonpath='{.metadata.generation}')
    acc=$(kubectl -n "$ns" get "$name" -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}/{.status.conditions[?(@.type=="Accepted")].observedGeneration}')
    if [[ $kind != apisixupstream && $class != "$want_class" ]]; then
      fail "$name has ingressClassName '$class', want $want_class"
    elif [[ $acc == "True/$gen" ]]; then
      ok "$name Accepted for generation $gen"
    else
      fail "$name not Accepted for generation $gen (status: $acc)"
    fi
  done
done

echo "== HTTPRoute"
hr=don-api-apisix-http-route
backend=$(kubectl -n "$ns" get httproute $hr -o jsonpath='{.spec.rules[0].backendRefs[0].namespace}/{.spec.rules[0].backendRefs[0].name}')
[[ $backend == "$gw_ns/$gw-gateway" ]] && ok "$hr points to $backend" || fail "$hr points to $backend, want $gw_ns/$gw-gateway"
for c in Accepted ResolvedRefs; do
  s=$(kubectl -n "$ns" get httproute $hr -o jsonpath="{.status.parents[0].conditions[?(@.type==\"$c\")].status}")
  [[ $s == True ]] && ok "$hr $c=True" || fail "$hr $c=$s"
done

echo "== Gateway pods in $gw_ns"
sel="app.kubernetes.io/name=apisix,app.kubernetes.io/instance=$gw"
kubectl -n $gw_ns get pods -l "$sel" -o custom-columns='POD:.metadata.name,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,LAST:.status.containerStatuses[0].lastState.terminated.reason' | sed 's/^/  /'
notready=$(kubectl -n $gw_ns get pods -l "$sel" -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -vc true)
[[ $notready == 0 ]] && ok "all gateway pods Ready" || fail "$notready gateway pod(s) not Ready"
ctrl_err=$(kubectl -n $gw_ns logs -l "app.kubernetes.io/instance=$gw,app.kubernetes.io/name=ingress-controller" -c manager --since=10m 2>/dev/null | grep -ciE '"level":"error"|\berror\b')
[[ $ctrl_err == 0 ]] && ok "no errors in controller log (10m)" || fail "$ctrl_err error line(s) in controller log (10m): kubectl -n $gw_ns logs -l app.kubernetes.io/instance=$gw,app.kubernetes.io/name=ingress-controller -c manager"

echo "== HTTP via $base"
marker="smoke-$(date +%s)-$RANDOM"
http() { curl -s -o /dev/null -w '%{http_code}' -A "$marker" "$@"; }
for p in /api-register/v1/openapi.json /schema-register/v1/openapi.json /tools/v1/openapi.json /oss-register/v1/openapi.json; do
  c=$(http "$base$p"); [[ $c == 200 ]] && ok "GET $p -> 200 (public)" || fail "GET $p -> $c, want 200"
done
for p in /api-register/v1/apis /schema-register/v1/schemas /oss-register/v1/repositories /tools/v1/events; do
  c=$(http "$base$p"); [[ $c == 401 ]] && ok "GET $p -> 401 (OPA denies without auth)" || fail "GET $p -> $c, want 401"
done
c=$(http "$base/does-not-exist-$marker"); [[ $c == 404 ]] && ok "GET unknown path -> 404" || fail "GET unknown path -> $c, want 404"
cors=$(curl -s -D - -o /dev/null -A "$marker" -H 'Origin: https://example.org' "$base/api-register/v1/openapi.json" | grep -ci '^access-control-allow-origin')
[[ $cors -ge 1 ]] && ok "CORS header present" || fail "no Access-Control-Allow-Origin header"

if [[ -n ${DON_API_KEY:-} ]]; then
  hdrs=$(curl -s -D - -o /dev/null -A "$marker" -H "x-api-key: $DON_API_KEY" "$base/api-register/v1/apis")
  code=$(head -1 <<<"$hdrs" | awk '{print $2}')
  [[ $code == 200 ]] && ok "GET /api-register/v1/apis with API key -> 200" || fail "GET /api-register/v1/apis with API key -> $code, want 200"
  grep -qi '^x-ratelimit-limit' <<<"$hdrs" && ok "limit-count active (X-RateLimit-Limit: $(grep -i '^x-ratelimit-limit' <<<"$hdrs" | cut -d' ' -f2 | tr -d '\r'))" \
    || fail "no X-RateLimit-Limit header: limit-count did not run"
else
  skip "authenticated request (set DON_API_KEY)"
fi

echo "== Traffic goes through $gw_ns/$gw"
sleep 2
new_hits=$(kubectl -n $gw_ns logs -l "$sel" --since=5m --tail=-1 2>/dev/null | grep -c "$marker")
old_hits=$(kubectl -n "$ns" logs -l app.kubernetes.io/name=apisix --since=5m --tail=-1 2>/dev/null | grep -c "$marker")
[[ $new_hits -gt 0 ]] && ok "$new_hits smoke request(s) in the log of $gw" || fail "no smoke requests in the log of $gw"
[[ $old_hits == 0 ]] && ok "no smoke requests in the old gateway in $ns" || fail "$old_hits smoke request(s) reached the old gateway in $ns"

echo
if [[ $fails == 0 ]]; then echo "PASS"; else echo "FAIL: $fails check(s)"; fi
exit $(( fails > 0 ))

#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
policy_yaml="$repository_root/apps/api/base/opa/opa-policy.yaml"
policy_tests="$repository_root/apps/api/base/opa/opa-policy_test.rego"
required_opa_version="1.18.2"
temporary_directory=$(mktemp -d)

cleanup() {
  rm -rf "$temporary_directory"
}
trap cleanup EXIT INT TERM

awk '
  /^  apisix\.rego: \|$/ {
    in_policy = 1
    next
  }
  in_policy && length($0) > 0 && !/^    / {
    exit
  }
  in_policy {
    sub(/^    /, "")
    print
  }
' "$policy_yaml" > "$temporary_directory/apisix.rego"

if command -v opa >/dev/null 2>&1 &&
  [ "$(opa version | awk '/^Version:/ { print $2 }')" = "$required_opa_version" ]; then
  opa test "$temporary_directory/apisix.rego" "$policy_tests"
  exit $?
fi

if command -v docker >/dev/null 2>&1; then
  docker run --rm \
    --volume "$temporary_directory:/policy:ro" \
    --volume "$policy_tests:/tests/opa-policy_test.rego:ro" \
    "openpolicyagent/opa:$required_opa_version" \
    test /policy/apisix.rego /tests/opa-policy_test.rego
  exit $?
fi

echo "OPA $required_opa_version of Docker is nodig om de policytests uit te voeren." >&2
exit 1

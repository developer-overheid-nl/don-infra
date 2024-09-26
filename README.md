# DON Infra

This repository contains all Kubernetes manifests for [developer.overheid.nl](https://developer.overheid.nl).

## Applications

The project is divided into multiple applications:

- [api](./apps/api/)
- [community](./apps/community/)
- [frontend](./apps/frontend/)
- [static](./apps/static/)

## SOPS public keys

All secrets are [encrypted with SOPS](https://digilab.overheid.nl/docs/digilab-onboarding/#secret-encryption), using the following public keys:

- api: `age17uzpswwz9g0frdfy7md5kvlvkcw6pkd9k3k2cad6mfe0zdvcm9pscyzd7v`
- community: `age122ph8qunemp7hz9hughd3nx65dlef4dcqu79c6psyn8se377w5hq486cdw`
- frontend: `age17n4n96sqw3rx7a5exuqascs69h8d3wux0746xvldae3x7kv4zu8q5m75pe`
- static: `age12k87tkhgdr7s309k6rcpss9x8df62tw9v0haxswtzd2mwr6jwacs858ac2`

## Creating secrets

Create a template file for a secret:

```bash
kubectl -n default create secret generic <SECRET> \
--from-literal=<KEY>=<VALUE> \
--dry-run=client \
-o yaml > <SECRET>.yaml
```

Encrypt:

```
sops \
  --encrypt \
  --encrypted-regex '^(data|stringData)$' \
  --age <PUBLIC KEY> \
  --in-place \
  <SECRET>.yaml
```

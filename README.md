# DON Infra

This repository contains all Kubernetes manifests for [developer.overheid.nl](https://developer.overheid.nl).

## Applications

The project is divided into multiple applications:

- [api](./apps/api/)
- [auth](./apps/auth/)
- [community](./apps/community/)
- [frontend](./apps/frontend/)
- [search](./apps/search/)
- [static](./apps/static/)

## Lokaal draaien

Zo draai je alle apps lokaal voor sneller experimenteren, zonder dat je de test-omgeving nodig hebt.

### Vereisten

| Tool | Installatie |
| --- | --- |
| [OrbStack](https://orbstack.dev) (Mac) of [Docker Desktop](https://www.docker.com/products/docker-desktop/) + [Kind](https://kind.sigs.k8s.io/) (Windows) | zie hieronder |
| `kubectl` | `brew install kubectl` / `choco install kubernetes-cli` |
| `flux` CLI | `brew install fluxcd/tap/flux` / `choco install flux` |
| `kustomize` | `brew install kustomize` / `choco install kustomize` |
| `jq` | `brew install jq` / `choco install jq` |
| [`task`](https://taskfile.dev) | `brew install go-task` / `choco install go-task` |

### Mac (OrbStack)

OrbStack start automatisch een K8s cluster. De Taskfile gebruikt de `orbstack` context.

```bash
brew install orbstack
# Start OrbStack via de app, daarna is kubectl automatisch geconfigureerd
```

### Windows

OrbStack werkt niet op Windows. Gebruik Kind met Docker Desktop:

```bash
# Docker Desktop installeren en K8s inschakelen via Settings → Kubernetes
# of Kind gebruiken:
kind create cluster --name don-local
```

Pas daarna in [Taskfile.yaml](./Taskfile.yaml) de `CONTEXT` var aan:

```yaml
vars:
  CONTEXT: kind-don-local   # of: docker-desktop
```

> **Ingress-DNS**: `*.k8s.orb.local` is OrbStack-specifiek en werkt niet op Windows.
> Gebruik op Windows altijd `task local:forward` (port-forward) in plaats van de ingress-hostnamen.

### Eerste keer opzetten

```bash
# 1. Flux installeren op de lokale cluster + namespaces aanmaken
task local:setup

# 2a. Secrets overnemen uit de test-cluster
#     Vind je context met: kubectl config get-contexts
task local:secrets:from-cluster TEST_CONTEXT=<naam-test-context>

# 2b. Of handmatig invullen vanuit de voorbeeldbestanden:
task local:secrets:from-examples
# → Pas de gegenereerde *-secret.yaml bestanden aan in elk overlays/local/
```

### Deployen en testen

```bash
# Preview wat er deployed wordt
task local:diff

# Alles deployen
task local:apply

# Laad daarna de declaratieve APISIX routes in de lokale admin API
task local:apisix:routes:sync

# Of per namespace:
task local:apply:api
task local:apply:auth
task local:apply:frontend
task local:apply:search
task local:apply:static
task local:apply:oss
```

Port-forwards per service:

```bash
task local:forward          # Apisix gateway :9080, admin :9180
task local:forward:auth     # Keycloak :8080
task local:forward:frontend # Frontend :3000
task local:forward:search   # Typesense :8108

# Optioneel: alleen een minimale OPA demo-route inladen
task local:apisix:opa-demo:configure
```

Lokale endpoints (OrbStack, via Ingress):

| Service | URL |
| --- | --- |
| Frontend | [don.k8s.orb.local](http://don.k8s.orb.local) |
| Apisix gateway | [api.k8s.orb.local](http://api.k8s.orb.local) |
| Apisix admin | [api-admin.k8s.orb.local](http://api-admin.k8s.orb.local) |
| API register site | [api-register.k8s.orb.local](http://api-register.k8s.orb.local) |
| Auth (Keycloak) | [auth.k8s.orb.local](http://auth.k8s.orb.local) |
| Search | [search.k8s.orb.local](http://search.k8s.orb.local) |
| Schema register | [schemas.k8s.orb.local](http://schemas.k8s.orb.local) |
| Static | [static.k8s.orb.local](http://static.k8s.orb.local) |
| OSS register | [oss-register.k8s.orb.local](http://oss-register.k8s.orb.local) |

### Opruimen

```bash
task local:teardown
```

### Alle beschikbare tasks

```bash
task --list
```

### Cluster inspecteren

**Snel via kubectl:**

```bash
# Werkt de cluster?
kubectl get nodes

# Alle pods in alle namespaces
kubectl get pods -A

# Pods in één namespace
kubectl get pods -n tn-don-api

# Logs van een pod bekijken
kubectl logs -n tn-don-api <pod-naam>

# Beschrijving van een pod (handig bij CrashLoopBackOff etc.)
kubectl describe pod -n tn-don-api <pod-naam>
```

**Aanbevolen: K9s** — terminal UI die je cluster live laat zien

```bash
brew install k9s   # of: choco install k9s
k9s                # opent direct in je huidige kubectl context
```

In K9s navigeer je met de pijltjestoetsen, `enter` om in te zoomen, `esc` om terug te gaan, `l` voor logs, `d` voor describe en `:` om te wisselen van resource type (bijv. `:pods`, `:namespaces`, `:helmreleases`).

**OrbStack (Mac only):** heeft ook een ingebouwde UI via de menubar-app waar je pods, logs en namespaces kunt bekijken zonder extra tooling.

---

## Connect to Postgres DB

Connect to the Kubernetes cluster and start a port-forward for the pgAdmin service:

```bash
kubectl port-forward svc/don-auth-pgadmin-pgadmin4 8888:80 -n tn-don-auth
```

Open the pgAdmin UI: http://localhost:8888 (sign in with: `chart@domain.com` / `SuperSecret`)

## SOPS public keys

All secrets are [encrypted with SOPS](https://digilab.overheid.nl/docs/digilab-onboarding/#secret-encryption), using the following public keys:

### Test

- api: `age17uzpswwz9g0frdfy7md5kvlvkcw6pkd9k3k2cad6mfe0zdvcm9pscyzd7v`
- auth: `age1jg3eun7lsymd3saszvynys3x8c5dk3q0m55qujyk9tgu4u8dk93ss86qwu`
- community: `age122ph8qunemp7hz9hughd3nx65dlef4dcqu79c6psyn8se377w5hq486cdw`
- frontend: `age17n4n96sqw3rx7a5exuqascs69h8d3wux0746xvldae3x7kv4zu8q5m75pe`
- search: `age1vg75nw5vk2vndzzud8sdvc5w9wtjz0ztejxrsuyg3dzjlpj9n5es94kzzn`
- static: `age12k87tkhgdr7s309k6rcpss9x8df62tw9v0haxswtzd2mwr6jwacs858ac2`
- analytics: `age1zy02fydy9s4e5x2lzut7red9rdk4njazet39htmskj63wqzxvuwqjw0jt0`
- oss: `age1ku5kl8lmkhfe6g0ednujus3tjwn2hc2msjk0dq70u40sc8u0cgzqgp34uy`

### Production

- api: `age1lt8huh6hzlcjg749dmptaad2wmssct5v99y8jz9yhd5xt62vcyyqg0z5j6`
- auth: `age13lfhkxpletvsxwz84p8nllgahsp8l350a2n7kdthh3tle78xgerqwhqk27`
- frontend: `age1gpl0td68sdh0u5q5dpcdh7dh3w5uzj9n0w3j6028hv0f5hqr2ysqq9mns0`
- search: `age16g3k56fseufjxsh3pmt07cg7llesz2crzaw6nq7l49j9gtrv24jqu4epuk`
- static: `age10jzjgvj847xvaqhknc2j0dreuutrr9tjmkek9xgse6h7nxlpdshsmf2l8q`
- analytics: `age1hfarccnhjakg4x8e6dsgmq8x4736f5vegavp3qtyp37xvs7fccvsqa0qsf`
- oss: `age1g59lru89pjncetzrnlr23cc4vq6rct5npsc9xcf89v26slm6g5msh579ue`

## Creating secrets

Create a template file for a secret:

```bash
kubectl create secret generic <SECRET> \
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

## create new schema
To create a new schema in the Postgres database, the digilab user can use the following command:
```bash
CREATE USER don_auth_adm WITH PASSWORD 'psw1';
CREATE USER don_auth_dml WITH PASSWORD 'psw2';
GRANT don_auth_adm TO digilab;
CREATE SCHEMA don_auth AUTHORIZATION don_auth_adm;
GRANT CONNECT ON DATABASE don TO don_auth_adm;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA don_auth TO don_auth_dml;

ALTER USER don_auth_adm SET SEARCH_PATH TO don_auth, public;
ALTER USER don_auth_dml SET SEARCH_PATH TO don_auth, public;
```

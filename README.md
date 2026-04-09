# DON Infra

Deze repository bevat alle Kubernetes-manifesten voor [developer.overheid.nl](https://developer.overheid.nl).

## Applicaties

Het project is opgedeeld in meerdere applicaties:

- [api](./apps/api/)
- [auth](./apps/auth/)
- [community](./apps/community/)
- [frontend](./apps/frontend/)
- [search](./apps/search/)
- [static](./apps/static/)

## SOPS publieke sleutels

Alle secrets zijn [versleuteld met SOPS](https://digilab.overheid.nl/docs/digilab-onboarding/#secret-encryption), met gebruik van de volgende publieke sleutels:

### Test

- api: `age17uzpswwz9g0frdfy7md5kvlvkcw6pkd9k3k2cad6mfe0zdvcm9pscyzd7v`
- auth: `age1jg3eun7lsymd3saszvynys3x8c5dk3q0m55qujyk9tgu4u8dk93ss86qwu`
- community: `age122ph8qunemp7hz9hughd3nx65dlef4dcqu79c6psyn8se377w5hq486cdw`
- frontend: `age17n4n96sqw3rx7a5exuqascs69h8d3wux0746xvldae3x7kv4zu8q5m75pe`
- search: `age1vg75nw5vk2vndzzud8sdvc5w9wtjz0ztejxrsuyg3dzjlpj9n5es94kzzn`
- static: `age12k87tkhgdr7s309k6rcpss9x8df62tw9v0haxswtzd2mwr6jwacs858ac2`
- analytics: `age1zy02fydy9s4e5x2lzut7red9rdk4njazet39htmskj63wqzxvuwqjw0jt0`
- oss: `age1ku5kl8lmkhfe6g0ednujus3tjwn2hc2msjk0dq70u40sc8u0cgzqgp34uy`

### Productie

- api: `age1lt8huh6hzlcjg749dmptaad2wmssct5v99y8jz9yhd5xt62vcyyqg0z5j6`
- auth: `age13lfhkxpletvsxwz84p8nllgahsp8l350a2n7kdthh3tle78xgerqwhqk27`
- frontend: `age1gpl0td68sdh0u5q5dpcdh7dh3w5uzj9n0w3j6028hv0f5hqr2ysqq9mns0`
- search: `age16g3k56fseufjxsh3pmt07cg7llesz2crzaw6nq7l49j9gtrv24jqu4epuk`
- static: `age10jzjgvj847xvaqhknc2j0dreuutrr9tjmkek9xgse6h7nxlpdshsmf2l8q`
- analytics: `age1hfarccnhjakg4x8e6dsgmq8x4736f5vegavp3qtyp37xvs7fccvsqa0qsf`
- oss: `age1g59lru89pjncetzrnlr23cc4vq6rct5npsc9xcf89v26slm6g5msh579ue`

## Secrets aanmaken

Maak een sjabloonbestand voor een secret:

```bash
kubectl create secret generic <SECRET> \
--from-literal=<KEY>=<VALUE> \
--dry-run=client \
-o yaml > <SECRET>.yaml
```

Versleutelen:

```
sops \
  --encrypt \
  --encrypted-regex '^(data|stringData)$' \
  --age <PUBLIC KEY> \
  --in-place \
  <SECRET>.yaml
```

## Nieuw schema aanmaken

Om een nieuw schema in de Postgres-database aan te maken, kan de `digilab` gebruiker het volgende commando gebruiken:

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

## Verbinden met de Postgres-database

Maak verbinding met het Kubernetes-cluster en start een port-forward voor de pgAdmin-service:

```bash
kubectl port-forward svc/don-auth-pgadmin-pgadmin4 8888:80 -n tn-don-auth
```

Open daarna de pgAdmin UI: http://localhost:8888 (inloggen met: `chart@domain.com` / `SuperSecret`)

## Lokaal draaien

Zo draai je alle apps lokaal voor sneller experimenteren, zonder dat je de test-omgeving nodig hebt.

### Vereisten

| Tool | Installatie |
| --- | --- |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) + [Kind](https://kind.sigs.k8s.io/) | zie hieronder |
| `bash` | macOS Terminal of op Windows via Git Bash / WSL |
| `kubectl` | `brew install kubectl` / `choco install kubernetes-cli` |
| `flux` CLI | `brew install fluxcd/tap/flux` / `choco install flux` |
| `kustomize` | `brew install kustomize` / `choco install kustomize` |
| `jq` | `brew install jq` / `choco install jq` |
| [`task`](https://taskfile.dev) | `brew install go-task` / `choco install go-task` |

### Cluster opzetten

```bash
# 1. Start Docker Desktop
# 2. Maak daarna een lokale Kind-cluster aan
kind create cluster --name don-local
```

De standaard `CONTEXT` in `Taskfile.yaml` staat al op `kind-don-local`. Alleen als je lokaal een andere clusternnaam gebruikt, moet je die variabele aanpassen:

```yaml
vars:
  CONTEXT: kind-don-local
```

Gebruik lokaal standaard port-forwards in plaats van ingress-hostnamen. Dat werkt hetzelfde op Mac en Windows.
Voer de tasks op Windows uit vanuit Git Bash of WSL; de scripts en commands in deze repository gaan uit van een POSIX-shell.

### Eerste keer opzetten

```bash
# 1. Flux installeren op de lokale cluster + namespaces aanmaken
task local:setup

# 2. Secrets handmatig aanmaken vanuit de voorbeeldbestanden
task local:secrets:from-examples
# → Pas de gegenereerde *-secret.yaml bestanden handmatig aan in elk overlays/local/
# → Dummy-gegevens zijn prima zolang je alleen de lokale setup wilt starten
#   en niet alle externe koppelingen echt hoeft te testen
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
task local:forward:api-register-site # API register site :4321
task local:forward:schemas  # Schema register :8000
task local:forward:static   # Static :8081
task local:forward:oss      # OSS register site :4322
task local:forward:search   # Typesense :8108

# Optioneel: alleen een minimale OPA demo-route inladen
task local:apisix:opa-demo:configure
```

Standaard lokale endpoints (via port-forward):

| Service | URL |
| --- | --- |
| Frontend | [http://localhost:3000](http://localhost:3000) |
| Apisix gateway | [http://localhost:9080](http://localhost:9080) |
| Apisix admin | [http://localhost:9180](http://localhost:9180) |
| API register site | [http://localhost:4321](http://localhost:4321) |
| Auth (Keycloak) | [http://localhost:8080](http://localhost:8080) |
| Search | [http://localhost:8108](http://localhost:8108) |
| Schema register | [http://localhost:8000](http://localhost:8000) |
| Static | [http://localhost:8081](http://localhost:8081) |
| OSS register site | [http://localhost:4322](http://localhost:4322) |

Optioneel: de `*.k8s.orb.local` hostnamen in de lokale overlays zijn alleen bruikbaar als je zelf een lokale ingress/DNS-oplossing hebt die die hostnamen resolve't. Dat is geen onderdeel van de standaard lokale setup.

### Opruimen

```bash
# Volledige lokale Kind-cluster verwijderen
task local:teardown

# Alleen de lokale namespaces verwijderen, maar de cluster laten bestaan
task local:teardown:namespaces
```

Opnieuw lokaal testen vanaf een schone omgeving:

```bash
task local:teardown
kind create cluster --name don-local
task local:setup
task local:secrets:from-examples
task local:apply
task local:apisix:routes:sync
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

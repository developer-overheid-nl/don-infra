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

## Connect to Postgres DB

Connect to the Kubernetes cluster and start a port-forward for the pgAdmin service:

```bash
kubectl port-forward svc/don-community-pgadmin-pgadmin4 8888:80 -n tn-don-community
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

### Production

- frontend: `age1gpl0td68sdh0u5q5dpcdh7dh3w5uzj9n0w3j6028hv0f5hqr2ysqq9mns0`
- search: `age16g3k56fseufjxsh3pmt07cg7llesz2crzaw6nq7l49j9gtrv24jqu4epuk`
- static: `age10jzjgvj847xvaqhknc2j0dreuutrr9tjmkek9xgse6h7nxlpdshsmf2l8q`

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


kubectl create secret generic keycloak-login-secret \
  --from-literal=admin-user=don \
  --from-literal=admin-password=d6PPnSFko8L4scs78z4m6KMXPAiCihRc \
  --from-literal=db-host=rg-apps-sandbox-westeu-001-psql-1.postgres.database.azure.com \
  --from-literal=db-name=don \
  --from-literal=db-user=don_auth_adm \
  --from-literal=db-password=Dmq8iEnhynn4qdzjTmD7rpgnXMKK \
  --dry-run=client -o yaml > keycloak-secret.yaml

  sops \
  --encrypt \
  --encrypted-regex '^(data|stringData)$' \
  --age age1jg3eun7lsymd3saszvynys3x8c5dk3q0m55qujyk9tgu4u8dk93ss86qwu \
  --in-place \
 keycloak-secret.yaml
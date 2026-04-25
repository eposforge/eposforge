# Secrets & Key Management — Implementation Catalog

> **Snapshot date:** 2026-04. Verify current details before adopting.

Candidate Adapters for the Secrets & Key Management slot
([../01-architecture/02-components/12-secrets-key-management.md](../01-architecture/02-components/12-secrets-key-management.md)).
A Secrets & Key Management Adapter resolves, rotates, and redacts
every secret the factory or its dispatched work consumes — vendor
API keys, deploy keys, service credentials, signing keys.

This catalog is **not exhaustive** and **not an endorsement**. A
single mismanaged secret can compromise the entire factory; pick
deliberately.

---

## How to read this catalog

Each entry includes (where known):

- **Type** — encrypted file, secret server, password manager, KMS.
- **Cost tier** — free-OSS, consumer-paid, commercial.
- **Store backends** — environments where secrets can live (file,
  server, KMS, manager).
- **Capabilities** — rotation support, injection modes, audit hooks.
- **Notes** — anything notable for Adapter authors.

---

## Encrypted-file secret stores

### SOPS

- **Type:** encryption wrapper for YAML / JSON / dotenv files.
- **Cost tier:** free OSS.
- **Store backends:** files in source control.
- **Capabilities:** per-key encryption, multi-recipient key support,
  age / GPG / cloud KMS as encryption backends.
- **Notes:** common Phase-0 choice — secrets live encrypted in the
  same Git repo as the configuration that consumes them. Adapter
  decrypts at runtime; Vault often lands later as the rotation
  point.

### age

- **Type:** modern file encryption tool.
- **Cost tier:** free OSS.
- **Store backends:** files (used as the encryption backend for
  SOPS in many instances).
- **Capabilities:** small, modern key format (X25519); simple CLI;
  scriptable.
- **Notes:** typically paired with SOPS rather than used standalone.
  The age private key itself is a secret; in mature instances it
  lives in Vault or a hardware token.

### git-crypt

- **Type:** transparent file encryption inside Git.
- **Cost tier:** free OSS.
- **Store backends:** files in source control.
- **Capabilities:** GPG-based per-file encryption, transparent on
  checkout for authorized users.
- **Notes:** alternative to SOPS for instances that prefer
  transparent encryption over per-key encryption.

---

## Secret servers

### HashiCorp Vault

- **Type:** secret server.
- **Cost tier:** free OSS; commercial Enterprise tier.
- **Store backends:** in-process; can also broker to KMS.
- **Capabilities:** dynamic secret issuance, lease + revocation,
  rotation without downtime, fine-grained policies, audit log,
  PKI / SSH / database secret engines.
- **Notes:** strong target for mature instances. The slot's
  rotation contract is naturally served by Vault's lease model.
  Adapter resolves secrets via short-lived tokens issued per
  agent identity.

### HashiCorp Boundary

- **Type:** zero-trust access broker (paired with Vault).
- **Cost tier:** free OSS; commercial tier.
- **Store backends:** brokers to other secret stores including
  Vault.
- **Capabilities:** identity-based access to targets without
  distributing long-lived credentials.
- **Notes:** complements Vault rather than replacing it. Useful
  when factory humans or agents need access to backend systems
  (databases, SSH targets) without ever holding their credentials.

### Cloud KMS (AWS KMS / GCP KMS / Azure Key Vault)

- **Type:** managed KMS / secret store.
- **Cost tier:** commercial (per-key + per-call pricing).
- **Store backends:** vendor-managed.
- **Capabilities:** hardware-backed keys, IAM-integrated policies,
  envelope encryption.
- **Notes:** appropriate when the factory already runs in a cloud
  account or needs hardware-backed key custody. Often used as the
  encryption backend for SOPS in cloud-native instances.

---

## Password managers

### Keeper Business

- **Type:** enterprise password manager with secrets-management
  add-on.
- **Cost tier:** commercial.
- **Store backends:** vendor-hosted vault.
- **Capabilities:** centralized secret custody, role-based sharing,
  audit log, machine-readable retrieval API for CI / agent use.
- **Notes:** valid choice for instances that already use Keeper for
  human credentials and want one source of truth across humans and
  machines. Adapter fetches at runtime via Keeper's API; pair with
  short-lived caching to limit blast radius.

### 1Password Connect / Service Accounts

- **Type:** password manager with machine-access surface.
- **Cost tier:** commercial.
- **Store backends:** vendor-hosted vault.
- **Capabilities:** programmatic secret retrieval, scoped service
  accounts, per-vault access policies.
- **Notes:** alternative to Keeper for instances on the 1Password
  ecosystem.

### Doppler

- **Type:** SaaS secrets manager.
- **Cost tier:** consumer-paid; commercial tiers.
- **Store backends:** vendor-hosted.
- **Capabilities:** environment-scoped secrets, integrations with
  most CI engines and runtimes.
- **Notes:** lower-friction option for instances that want a SaaS
  secrets layer without running Vault.

---

## Floor option: env vars on host

- **Type:** plain environment variables.
- **Cost tier:** free.
- **Store backends:** OS environment, dotenv files outside source
  control.
- **Capabilities:** none beyond what the OS provides.
- **Notes:** the floor option. Acceptable as a starting point for
  development workstations but not for production. The Adapter
  must still emit `secret.accessed` events and enforce redaction.

---

## Migration patterns

A common maturity path inside a factory instance:

1. **Bootstrap:** env vars on host + dotenv files outside source
   control.
2. **Phase 0:** SOPS + age — secrets encrypted in Git.
3. **Phase 0–1:** Vault deployed; age key lives in Vault; secrets
   rotate through Vault.
4. **Mature:** Keeper Business (or equivalent) as the human-facing
   source of truth; Vault brokers machine-facing secrets; Boundary
   gates target access.

Each step preserves the Adapter contract — only the backends and
runtime resolution change.

---

## Contribution

Open a PR adding new entries with the same fields. Prefer Adapters
with rotation support and explicit redaction behavior at the
emitter layer.

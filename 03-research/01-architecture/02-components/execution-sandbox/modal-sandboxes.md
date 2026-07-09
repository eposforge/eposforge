---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Modal Sandboxes as an Execution Sandbox Adapter

> **Snapshot date:** 2026-07. Product surface and pricing change frequently.
> Verify against [modal.com/docs](https://modal.com/docs) before adopting.
> This note is recon, not an endorsement and not a Living Spec.

Deep-dive research on [Modal](https://modal.com/) for the **Execution
Sandbox** slot
([../../../../01-architecture/02-components/execution-sandbox.md](../../../../01-architecture/02-components/execution-sandbox.md)).
Secondary fit for the Inference Layer is summarized at the end; primary
placement is Component 7.

Companion catalog entry:
[execution-sandbox.md](./execution-sandbox.md).

---

## Why this candidate

Modal sells AI infrastructure (inference, training, batch, sandboxes).
Only the **Sandbox** product maps cleanly onto an EposForge component
contract today. Modal Sandboxes are purpose-built for:

- executing untrusted / LLM-generated code
- isolated agent sessions at high concurrency
- resource-limited ephemeral containers with programmatic lifecycle

That is exactly the Execution Sandbox role: *fresh isolated workspace
per dispatched sub-task, resource limits, network policy, teardown,
audit-oriented lifecycle signals*.

Modal is **not** a dark-factory pattern competitor. It is a vendor
substrate that would appear as an Adapter under `.eposforge/` on an
adopting instance — if and only if privacy posture and cost model fit.

---

## Product surface (sandbox-relevant)

| Capability | Modal surface | Notes |
|---|---|---|
| Create / exec / terminate | `modal.Sandbox.create`, `exec`, `terminate`, `detach` | Python, JS, Go SDKs |
| Lifecycle events | Created → Scheduled → Started → Ready → Finished | Maps to audit create/terminate |
| Timeouts | Default 5 min; max 24 h; `idle_timeout` | Wall-clock limit from Router |
| Resource limits | `cpu` / `memory` request + hard limits; `ephemeral_disk` | OOM kill on memory hard limit |
| Network policy | `block_network`, CIDR allowlist, domain allowlist (beta), runtime policy update (alpha) | Strong egress story |
| Isolation | **gVisor** by default; **VM Sandboxes** (alpha/beta) for full kernel | gVisor > plain Docker namespaces |
| GPU | GPU-attachable sandboxes; GPU subject to preemption | GPU VMs not supported (VM runtime) |
| Artifacts | Filesystem API, Volumes, CloudBucketMounts, filesystem/directory snapshots | Return path for sub-task outputs |
| Observability | Dashboard logs/metrics; readiness probes; exit codes | Plan-dependent log retention |
| Concurrency | Claims 100k+ concurrent sandboxes; sub-second scheduling | Burst scale without cluster ops |
| Compliance | SOC 2 Type 2; HIPAA (BAA on Enterprise, scoped) | Vendor cloud; not local |

Sources: Modal docs for [Sandboxes](https://modal.com/docs/guide/sandbox),
[networking](https://modal.com/docs/guide/sandbox-networking),
[resources](https://modal.com/docs/guide/resources),
[snapshots](https://modal.com/docs/guide/sandbox-snapshots),
[security](https://modal.com/docs/guide/security),
[VM sandboxes](https://modal.com/docs/guide/vm-sandboxes),
[sandbox pricing](https://modal.com/docs/guide/sandbox-resources).

---

## Contract fit (Execution Sandbox)

Contract requirements from
[execution-sandbox.md](../../../../01-architecture/02-components/execution-sandbox.md):

| Contract requirement | Modal fit | How |
|---|---|---|
| Fresh, isolated workspace per sub-task | **Strong** | `Sandbox.create` allocates a new container/VM; no shared host process space with the factory |
| Resource limits (CPU, memory, wall clock, egress budget) | **Strong** | CPU/memory request+limit; timeout / idle_timeout; egress via block/allowlist (egress *budget* would be adapter-side metering) |
| Enforce Dev Product privacy posture | **Partial / posture-dependent** | `block_network=True` or tight allowlists can honor "no outbound except approved channels" **for code inside the sandbox**. The sandbox itself still runs on Modal's cloud → **cannot** satisfy `privacy: local` for the *workload location* |
| Clean teardown; surface artifacts | **Strong** | `terminate` + exit codes; filesystem copy-out / Volume commit / snapshots as artifact return path |
| Audit events on create, terminate, policy violation | **Partial** | Lifecycle events + exit codes + dashboard logs are available; blocked domain connections are logged to system output. Full mapping to Audit & Observability is adapter work (webhook/export/SDK poll). Enterprise audit logs exist for workspace actions |

### Required Adapter metadata (proposed draft)

If an instance authored a Modal Execution Sandbox Adapter:

| Field | Candidate value |
|---|---|
| `isolation_mechanism` | `gvisor-container` (default) or `vm` (experimental_options vm_runtime) |
| `network_policy_modes` | `block_all`, `cidr_allowlist`, `domain_allowlist` (beta), `open_public`, `dynamic_update` (alpha) |
| `gpu_support` | `true` for gVisor sandboxes; `false` for VM runtime |
| `state_persistence` | default `false` per sub-task; optional Volume / filesystem snapshot for cross-invocation (declare explicitly) |
| `privacy_posture` | `vendor` / not `local` — cloud execution always |
| `cost_hint` | metered per-second CPU/memory/GPU; scale-to-zero between tasks |
| `invocation_surface` | Modal SDK (Python primary; JS/Go available) |

---

## Network and privacy model (critical)

Default Modal Sandbox: **no inbound** from the public internet; **full
outbound** to any public IP. That default is **unsafe** for privacy-
sensitive factory dispatches until the Adapter tightens policy.

Modal's outbound controls (as of this snapshot):

1. **`block_network=True`** — drop all outbound traffic.
2. **`outbound_cidr_allowlist`** — only listed CIDRs.
3. **`outbound_domain_allowlist`** (beta) — TLS:443 only to listed
   domains (supports `*.` wildcards); non-TLS blocked unless CIDR-
   allowed.
4. **Runtime policy update** (alpha/experimental) — narrow or open
   allowlists mid-session (e.g. install deps → lock down).

Implications for EposForge:

- **`privacy: local` Dev Products** must **not** be dispatched to a
  Modal sandbox. Location is vendor cloud; data leaves the host. Use
  Docker / Firecracker / local namespace adapters instead.
- **Vendor-allowed Dev Products** can use Modal with:
  - `block_network=True` when the agent needs no egress, or
  - domain/CIDR allowlist limited to approved Tool Transport and
    inference endpoints, with secrets injected only via Secrets & Key
    Management → Modal Secrets (never baked into images).
- Dynamic policy (alpha) is attractive for "bootstrap then lockdown"
  agent sessions but should not be relied on as normative until
  stable.

Security model notes from Modal: sandboxes use **gVisor** (stronger
syscall isolation than plain Docker); sandboxes are **not** authorized
to access other Modal workspace resources the way Functions are by
default — blast radius limited to the sandbox container.

---

## Lifecycle mapping (Router → Sandbox → Audit)

```text
Router dispatches sub-task
        │
        ▼
Adapter: Sandbox.create(
            image=named_or_snapshot,
            timeout=wall_clock,
            cpu=(req, lim), memory=(req, lim),
            block_network | outbound_*_allowlist,
            secrets=[...],
            volumes={...}  # optional artifact mount
         )
        │  audit: sandbox.created {id, task_id, posture}
        ▼
Ready probe (optional) → wait_until_ready
        │
        ▼
Inject workspace (filesystem API / Volume subpath / git clone if egress allows)
        │
        ▼
sb.exec(dev_product_command...)  # or entrypoint
        │
        ▼
Collect artifacts (filesystem.copy_to_local / Volume / snapshot)
        │
        ▼
sb.terminate(wait=True); sb.detach()
        │  audit: sandbox.finished {id, returncode, duration, cost}
```

**Wall clock:** prefer Router-declared timeout over Modal's 5-minute
default. For sessions needing >24 h, Modal recommends filesystem
snapshot + restore (not a continuous single sandbox).

**Idle timeout:** useful for interactive agent sessions that should die
when no exec/stdin/tunnel activity remains — reduces cost leakage.

---

## Isolation comparison (catalog peers)

| Candidate | Isolation | Egress control | Local privacy | Ops burden | Burst scale |
|---|---|---|---|---|---|
| Docker containers | namespaces + cgroups | good (self-managed) | yes | low on single host | host-bound |
| K8s ephemeral pods | namespaces + NetworkPolicy | strong | yes (private cluster) | medium–high | cluster-bound |
| Firecracker | KVM micro-VM | strong if wired | yes | high | host-bound |
| OpenClaw | containerized gateway + browser | per-instance | yes | medium | host-bound |
| **Modal Sandboxes** | **gVisor** (+ VM option) | **strong API-native** | **no** | **low** (vendor) | **very high** |

Modal wins on **elastic concurrency without owning a GPU/CPU fleet**
and on **first-class egress policy API**. It loses on **data locality /
privacy: local** and on **dependency on a commercial third party**.

Firecracker remains the strongest **self-hosted** isolation choice for
untrusted code. Modal is the strongest **hosted** option in this
catalog for agent-scale isolation.

---

## Gaps and adapter design risks

1. **Privacy locality** — cannot fill the slot for local-only work.
   Factories with mixed posture still need a local sandbox Adapter
   alongside Modal (multi-adapter pattern, same as Inference).

2. **Audit integration** — Modal has logs, lifecycle states, and
   Enterprise audit logs; the EposForge Adapter must still emit
   normative audit events into Audit & Observability (Component 11).
   Do not treat the Modal dashboard as the factory system of record.

3. **Egress budget** — contract mentions network egress *budget*;
   Modal provides block/allowlist, not a metered byte budget. Budget
   would be approximate (duration × assumed bandwidth) or custom.

4. **Browser capability** — catalog peers (e.g. OpenClaw) expose
   headless/VNC/CDP browser. Modal provides a general container;
   browser is DIY (install Chrome in image) unless the instance
   composes Modal with a browser-capable Dev Product image.

5. **GPU preemption** — GPU sandboxes can be preempted; adapters must
   handle restart/snapshot for GPU agent work.

6. **VM runtime limits** — full VM is better for Docker-in-Docker and
   kernel features, but: no GPU, static memory, some API gaps
   (volume reload, memory snapshots). Prefer gVisor default unless
   nested containers are required.

7. **Secrets** — Modal Secrets inject env vars into the sandbox. The
   Adapter must pull material only via Secrets & Key Management and
   never log secret values. Prefer short-lived scoped credentials.

8. **State persistence default** — pattern prefers ephemeral per
   sub-task. Volumes and snapshots are powerful but easy to misuse
   into long-lived "pets." Adapter default: no Volume; opt-in for
   multi-step deliverables with explicit `state_persistence: true`.

9. **Cost attribution** — pay `max(request, actual)` per second. Poor
   request sizing wastes money; missing hard limits let agents burn
   memory. Adapter should set **hard memory/CPU limits** from Router
   policy always.

10. **SDK / client surface** — create/exec from outside Modal (factory
    host or Router process) is supported; requires Modal token via
    Secrets. JS/Go clients exist for non-Python Routers.

---

## When Modal is a good Execution Sandbox choice

Use / shortlist Modal when **all** of the following hold:

- Dev Product privacy posture allows **vendor** execution.
- Dispatch volume is **bursty** or **high concurrency** (many parallel
  agent sessions) and self-hosting that capacity is undesirable.
- Isolation stronger than plain Docker is wanted without operating
  Firecracker/K8s yourself.
- Network policy must be **API-declarable** per task (block /
  allowlist / domain).
- Operator accepts SOC2/HIPAA-scoped commercial cloud and second-based
  billing.

Prefer **not** Modal when:

- Any `privacy: local` requirement applies to the sub-task.
- Offline / air-gapped / on-prem-only substrate is required.
- Browser-native sandbox is the primary need (evaluate OpenClaw or
  specialized browser sandboxes first).
- The instance already has spare host capacity and simple Docker
  isolation is enough (lower cost and complexity).

---

## Sketch: Adapter responsibilities

Normative contract lives in the component doc; this is research only.

1. **Map Router resource hints** → `cpu`, `memory`, `timeout`,
   `idle_timeout`, optional GPU type.
2. **Map privacy / network policy** → `block_network` or allowlists;
   refuse dispatch if posture is `local`.
3. **Build or select image** — prefer named prebuilt images
   (`Image.from_name`) so create path does not block on rebuilds;
   align with deliverable `.devcontainer` / base toolchain where
   possible.
4. **Inject secrets** from Secrets & Key Management into Modal
   Secrets for that sandbox only.
5. **Run Dev Product** via `exec` or entrypoint; stream logs to Audit.
6. **Collect artifacts** via filesystem API or Volume subpath; hand
   off to Source Control + CI or the agreed return path.
7. **Terminate + detach**; record return code, duration, approximate
   cost.

Optional advanced: filesystem snapshot keyed by session for
multi-turn agent work; warm pool of pre-started sandboxes for latency.

---

## Secondary fit: Inference Layer

Modal also hosts GPU inference (Functions / inference product): scale-
to-zero model servers, multi-GPU, OpenAI-compatible patterns depending
on how the operator packages the model.

| Inference contract aspect | Modal as Inference Adapter |
|---|---|
| Serve models with declared privacy | `vendor` only (not `local`) |
| Cost metering | second-based GPU/CPU → map to Audit |
| Tool calling / streaming | depends on engine you deploy (vLLM, etc.), not Modal itself |
| Secrets | Modal Secrets + EposForge Secrets slot |

**Assessment:** Modal Inference is a **hosted self-managed engine host**
(closer to "run vLLM on someone else's GPUs" than to Anthropic/OpenAI
as a model vendor). It is a reasonable Inference catalog entry of type
`hosted self-managed`, but it is a **weaker unique fit** than
Execution Sandbox: Ollama/vLLM already cover local engines, and
frontier vendor APIs cover managed models. Modal shines when the
factory needs **elastic GPU serving without owning GPUs**.

Do **not** conflate the two slots: a Modal **Sandbox** Adapter and a
Modal **Inference** Adapter would be separate plugins with separate
metadata, even if they share a workspace token.

---

## Relationship to Platform Factory substrate

Cognee / architecture place serverless compute as a **future Substrate
Tier extension**. Modal Functions + Sandboxes are that shape. Installing
a Modal Execution Sandbox Adapter is a **Product/Platform factory
choice**, not a change to the pattern ontology. No new component is
required.

---

## Recommendation

| Decision | Guidance |
|---|---|
| Pattern change needed? | **No** |
| Primary slot | **Execution Sandbox (Component 7)** |
| Secondary slot | Inference Layer as hosted GPU engine host (optional, separate adapter) |
| Catalog action | Add Modal to the Execution Sandbox implementation catalog (done alongside this note) |
| Implementation priority | **Low–medium** — pursue when an adopting instance needs bursty vendor-privacy agent sandboxes; not required for local-first self-host |
| Next engineering step if pursued | Spike Adapter: create → policy → exec → artifact → terminate; measure cold start, cost per sub-task, audit event completeness; document refuse path for `privacy: local` |

---

## Sources (primary)

- https://modal.com/
- https://modal.com/products/sandboxes
- https://modal.com/docs/guide/sandbox
- https://modal.com/docs/guide/sandbox-networking
- https://modal.com/docs/guide/sandbox-files
- https://modal.com/docs/guide/sandbox-snapshots
- https://modal.com/docs/guide/sandbox-resources
- https://modal.com/docs/guide/resources
- https://modal.com/docs/guide/vm-sandboxes
- https://modal.com/docs/guide/security
- EposForge contract:
  `01-architecture/02-components/execution-sandbox.md`
- Peer catalog: `03-research/01-architecture/02-components/execution-sandbox/execution-sandbox.md`

---

## Contribution / refresh

When Modal ships FQDN egress GA, stable dynamic policy, or changes
default isolation (gVisor vs VM), update this note and the catalog
entry in the same change. Prefer verifying prices and plan limits on
[modal.com/pricing](https://modal.com/pricing) rather than freezing
dollar figures here.

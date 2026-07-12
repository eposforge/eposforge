---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Execution Sandbox — Implementation Catalog

> **Snapshot date:** 2026-07. Verify current details before adopting.

Candidate Adapters for the Execution Sandbox slot
([../../01-architecture/02-components/execution-sandbox.md](../../01-architecture/02-components/execution-sandbox.md)).
An Execution Sandbox Adapter provides isolated, ephemeral runtimes
for dispatched Dev Product work — shell, filesystem, browser, and
network capabilities under strict isolation.

This catalog is **not exhaustive** and **not an endorsement**.

---

## How to read this catalog

Each entry includes (where known):

- **Type** — container, micro-VM, devcontainer, agent sandbox.
- **Cost tier** — free-OSS, consumer-paid, commercial.
- **Isolation mechanism** — how the sandbox isolates from the host.
- **Capabilities** — shell, fs, browser, GPU, network policy modes.
- **Notes** — anything notable for Adapter authors.

---

## Candidates

### OpenClaw

- **Type:** open-source agent gateway + sandbox browser.
- **Cost tier:** free OSS.
- **Isolation mechanism:** containerized sandbox (gateway + browser
  containers); host network optional.
- **Capabilities:** shell ops, fs ops, headless / VNC / noVNC /
  Chrome DevTools Protocol browser; integrates cleanly with Tool
  Transport (MCP) for browser and shell capabilities.
- **Notes:** dual-fit — also listed in
  [dev-products.md](../dev-product/dev-products.md). When OpenClaw fills the
  Execution Sandbox slot, Dev Product Adapters dispatched into it
  inherit its network and isolation posture; declare
  `network_policy_modes` per instance. **ToS caveat:** running a
  ToS-restricted Dev Product (e.g. Gemini / Claude on OAuth) inside the
  sandbox does not launder its terms — the dispatched Adapter still needs
  BYOK / API-key auth to satisfy `autonomous` mode. See
  [../../01-architecture/03-autonomy-modes/autonomy-modes.md](../../01-architecture/03-autonomy-modes/autonomy-modes.md).

### Docker containers

- **Type:** general container runtime.
- **Cost tier:** free OSS (Docker Engine); commercial Docker Desktop.
- **Isolation mechanism:** Linux namespaces + cgroups.
- **Capabilities:** shell, fs, network policies via Docker network
  settings; GPU via nvidia-container-toolkit.
- **Notes:** the floor option for self-hosted instances. Adapter
  spins a fresh container per dispatched sub-task; tear down on
  completion. Good fit when the operator already runs Docker for
  service hosting.

### Devcontainers / remote devcontainers

- **Type:** standardized Docker-based development environment
  (devcontainers spec).
- **Cost tier:** free OSS.
- **Isolation mechanism:** container with declared base image, tools,
  and configuration.
- **Capabilities:** reproducible per-repo environments; integrates
  with VS Code Remote and GitHub Codespaces.
- **Notes:** strong fit when each deliverable repo declares its own
  devcontainer — the sandbox spec lives next to the code it builds.
  Adapter consumes `.devcontainer/devcontainer.json`.

### Goose container

- **Type:** containerized run mode for the Goose agent.
- **Cost tier:** free OSS.
- **Isolation mechanism:** Docker container.
- **Capabilities:** runs Goose agent operations inside the sandbox;
  good privacy posture for fully local operation.
- **Notes:** useful in instances where Goose is also the chosen Dev
  Product. Adapter scopes filesystem and network egress per
  dispatched sub-task.

### Kubernetes ephemeral pods

- **Type:** orchestrated container runtime.
- **Cost tier:** free OSS (cluster cost varies).
- **Isolation mechanism:** Linux namespaces + cgroups + pod
  network policies.
- **Capabilities:** strong network policy enforcement, multi-host
  scheduling, GPU scheduling via device plugins.
- **Notes:** appropriate when the factory already runs on
  Kubernetes. Heavier than plain Docker for single-host instances.

### Firecracker micro-VMs

- **Type:** open-source KVM microVMM (Apache 2.0); AWS-origin, used for
  multi-tenant serverless-class isolation
  ([firecracker-microvm.github.io](https://firecracker-microvm.github.io/)).
- **Cost tier:** free OSS (host capacity + operator cost only).
- **Isolation mechanism:** hardware-virtualized microVM (separate guest
  kernel) + minimal device model (virtio-net/block/vsock, serial); production
  posture adds the **jailer** (chroot, cgroups, drop privileges, optional
  netns/PID ns). Stronger than shared-kernel containers.
- **Capabilities:** ≤~125 ms cold path to guest init (upstream SLA on
  reference hosts); &lt;5 MiB VMM overhead class; virtio rate limiters for
  net/block; snapshot/restore for warm start; REST API over Unix socket.
  **No GPU passthrough.** Egress policy is host-side (TAP +
  iptables/nftables/CNI/netns), not a productized allowlist DSL. Higher-level
  wrappers (firecracker-containerd, Kata+Firecracker) improve OCI/K8s
  ergonomics.
- **Notes:** best **self-hosted** isolation fit in this catalog for
  untrusted Dev Product code and `privacy: local` when the operator can
  staff KVM hosts, rootfs pipelines, and network glue. Not turnkey — the
  Adapter owns lifecycle, artifacts, audit events, and cleanup. Route GPU
  sub-tasks to another Adapter. Deep research:
  [firecracker-microvms.md](./firecracker-microvms.md).

### Modal Sandboxes

- **Type:** hosted gVisor container sandbox (optional full VM runtime);
  commercial AI infrastructure vendor ([modal.com](https://modal.com/)).
- **Cost tier:** commercial; pay-per-second CPU/memory/GPU (free credit
  tier may exist — verify current pricing).
- **Isolation mechanism:** gVisor by default (stronger than plain Docker
  namespaces); VM Sandboxes (experimental) for full Linux kernel /
  Docker-in-Docker. Sandboxes are not authorized to other Modal
  workspace resources by default.
- **Capabilities:** shell and arbitrary images; filesystem API +
  Volumes for artifact I/O; GPU attach (preemptible; not on VM
  runtime); wall-clock and idle timeouts; readiness probes; lifecycle
  events (created → finished). Network policy modes: full block,
  CIDR allowlist, domain allowlist (beta), runtime policy update
  (alpha). High concurrency / scale-to-zero without self-managed
  cluster.
- **Notes:** best **hosted** fit in this catalog for bursty agent
  sandboxes when privacy posture allows **vendor** execution. **Cannot**
  satisfy `privacy: local` — compute runs on Modal's cloud. Adapter
  must refuse local-posture dispatches and always set hard resource
  limits. Deep research:
  [modal-sandboxes.md](./modal-sandboxes.md). Secondary (separate
  adapter): Modal as hosted GPU inference engine host — see Inference
  catalog if added later.

---

## Contribution

Open a PR adding new entries with the same fields. Prefer Adapters
with explicit network egress controls and clean teardown semantics
on sub-task completion.


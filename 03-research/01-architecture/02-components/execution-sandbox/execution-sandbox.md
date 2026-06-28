---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Execution Sandbox — Implementation Catalog

> **Snapshot date:** 2026-05. Verify current details before adopting.

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

- **Type:** minimal hypervisor for serverless / function workloads.
- **Cost tier:** free OSS.
- **Isolation mechanism:** KVM-based micro-VM.
- **Capabilities:** stronger isolation than containers; fast boot
  (~125 ms); minimal attack surface.
- **Notes:** strongest isolation choice in this catalog. Operationally
  heavier; consider when running untrusted Dev Product code or
  untrusted Spec Inputs.

---

## Contribution

Open a PR adding new entries with the same fields. Prefer Adapters
with explicit network egress controls and clean teardown semantics
on sub-task completion.


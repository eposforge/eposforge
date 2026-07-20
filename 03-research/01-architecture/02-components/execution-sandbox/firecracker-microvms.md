---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Firecracker microVMs as an Execution Sandbox Adapter

> **Snapshot date:** 2026-07. Verify against upstream docs before adopting.
> This note is recon, not an endorsement and not a Living Spec.

Deep-dive research on [Firecracker](https://firecracker-microvm.github.io/)
for the **Execution Sandbox** slot
([../../../../01-architecture/02-components/execution-sandbox.md](../../../../01-architecture/02-components/execution-sandbox.md)).
Primary placement is the Execution Sandbox. Secondary notes on orchestration
wrappers and GPU-adjacent alternatives appear where relevant.

Companion catalog entry:
[execution-sandbox.md](./execution-sandbox.md).

Peer deep-dive (hosted contrast):
[modal-sandboxes.md](./modal-sandboxes.md).

---

## Why this candidate

Firecracker is an open-source virtual machine monitor (VMM) that uses
Linux KVM to run **microVMs** — hardware-virtualized guests with a
minimal device model. It was built at AWS for multi-tenant serverless
(Lambda / Fargate-class isolation) and is Apache-2.0 licensed.

For EposForge it is a **self-hosted isolation substrate**, not a
dark-factory competitor. An adopting instance would install a Firecracker
Adapter under the Execution Sandbox slot when it needs stronger isolation
than containers **and** can keep workloads on operator-controlled hosts
(`privacy: local` capable).

It is the catalog’s reference for “strongest self-hosted isolation,”
but that label needs nuance: Firecracker itself is a low-level VMM.
Production agent sandboxes usually sit on **Firecracker + operator glue**
(rootfs pipeline, TAP/CNI networking, jailer, image/cache lifecycle) or
on a higher-level stack that embeds it (firecracker-containerd, Kata
Containers with Firecracker, hosted platforms that run Firecracker
under the hood).

---

## Product surface (sandbox-relevant)

| Capability | Firecracker surface | Notes |
|---|---|---|
| Create / configure / start | REST API over Unix socket; or `--config-file` JSON | Pre-boot config then `InstanceStart` |
| Isolation | KVM microVM; separate guest kernel per VM | No shared kernel with host or other guests |
| Defense in depth | **Jailer** companion binary | chroot/pivot_root, cgroups, drop privileges, optional netns + PID ns, seccomp (Firecracker process) |
| Device model | Minimal: virtio-net, virtio-block, virtio-vsock, serial console, minimal keyboard controller | Deliberately tiny attack surface vs QEMU |
| Resource limits | vCPU/memory via API; cgroups via jailer; **built-in rate limiters** on virtio net/block | Bandwidth and/or ops/sec; bursts supported |
| Networking | Host TAP device + guest virtio-net; optional netns via jailer | Egress policy is **host/operator** (iptables/nftables/CNI), not a first-class “block_network” API |
| Host↔guest IPC | vsock; MMDS (metadata service) | Prefer vsock over open network for Tool Transport bridge |
| Disk / workspace | virtio-block drives (rootfs + data disks) | Operator builds ext4 (or similar) rootfs images |
| Snapshot / restore | Full memory + device state snapshot | Cold boot ~≤125 ms to guest init (SLA); snapshot restore can be tens of ms in practice |
| GPU | **Not supported** (no PCIe/device passthrough beyond the fixed device model) | Use Cloud Hypervisor / QEMU / container GPU path for GPU agents |
| Control plane | Single Firecracker process per microVM | High density: &lt;5 MiB VMM overhead (1 vCPU / 128 MiB guest class) |
| Platforms | x86_64 and aarch64 Linux hosts with hardware virtualization | Nested virt depends on host; bare metal / KVM-capable hosts preferred |
| License / cost | Apache 2.0 OSS | Host hardware + ops cost only |

Official SLA-style claims (measured on EC2 metal-class hosts with free
resources; see upstream `SPECIFICATION.md`):

- VMM start to API socket: order of single-digit–tens of ms wall clock
- InstanceStart → guest `/sbin/init`: **≤ 125 ms** (minimal kernel/rootfs, serial off)
- VMM memory overhead: **≤ 5 MiB** for the 1 vCPU / 128 MiB reference config
- Creation rate: up to **~150 microVMs/s per host** (project marketing)
- Guest compute: claimed &gt;95% of bare metal (integration test pending upstream)

---

## Contract fit (Execution Sandbox)

Contract requirements from
[execution-sandbox.md](../../../../01-architecture/02-components/execution-sandbox.md):

| Contract requirement | Firecracker fit | How |
|---|---|---|
| Fresh, isolated workspace per sub-task | **Strong** | New microVM (+ optional clean rootfs overlay) per dispatch; hardware virtualization barrier |
| Resource limits (CPU, memory, wall clock, egress budget) | **Strong with adapter work** | vCPU/RAM via API; cgroups via jailer; wall clock via adapter kill timer; egress budget via host rate limiters + iptables metering |
| Enforce Dev Product privacy posture | **Strong for `privacy: local`** | Runs on operator substrate; can attach guest to netns with **no external route**, or allowlist host-side only. Vendor-posture also fine if host has outbound path |
| Clean teardown; surface artifacts | **Strong with adapter work** | Kill Firecracker process / graceful guest reboot; copy artifacts from block device, 9p-like share (if provided by wrapper), or vsock file transfer before destroy |
| Audit events on create, terminate, policy violation | **Partial** | Firecracker logs/metrics to named pipes; jailer lifecycle is operator-owned. Adapter must map start/stop/OOM/kill into Audit & Observability |

### Required Adapter metadata (proposed draft)

| Field | Candidate value |
|---|---|
| `isolation_mechanism` | `kvm-microvm` (Firecracker); optionally `kvm-microvm+jailer` |
| `network_policy_modes` | `none` (no virtio-net), `host_netns_isolated`, `egress_allowlist` (host firewall), `open` — all **adapter-defined**, not Firecracker-native enums |
| `gpu_support` | `false` for pure Firecracker |
| `state_persistence` | default `false`; optional snapshot restore or persistent data disk (declare explicitly) |
| `privacy_posture` | can honor `local` when host and egress policy are local |
| `cost_hint` | host-amortized (capacity cost), not vendor per-second |
| `invocation_surface` | REST over Unix socket + jailer CLI; or higher-level wrapper API |

---

## Isolation model (why it is stronger than Docker)

```text
                    ┌─────────────────────────────────────┐
 Host               │  jailer (chroot, cgroups, drop priv) │
                    │    └─ firecracker process (Rust)     │
                    │         └─ KVM                       │
                    │              └─ microVM guest kernel │
                    │                   └─ rootfs + agent │
                    └─────────────────────────────────────┘
```

Layers:

1. **Hardware virtualization (KVM)** — guest cannot share the host
   kernel; container escapes that depend on shared-kernel bugs do not
   apply the same way.
2. **Minimal device model** — only five emulated device classes;
   no broad PCI/USB/legacy emulation surface like general-purpose QEMU.
3. **Jailer** — if the VMM were compromised, the process is already
   constrained (chroot, namespaces, non-root uid/gid, cgroups,
   resource rlimits). Production guidance: always use jailer; demo
   “bare firecracker” paths are not production posture.
4. **Optional host netns** — jailer `--netns` joins a prepared network
   namespace so each sandbox has a private networking stack the Adapter
   controls.

This is why the catalog ranks Firecracker above plain Docker for
**untrusted Dev Product code** and **untrusted Spec Inputs**.

It does **not** make network policy free: a microVM with a bridged TAP
and full NAT is as open as a container with the same iptables rules.
Isolation of CPU/memory/kernel ≠ isolation of egress.

---

## Networking and privacy (critical for the contract)

Firecracker provides **the virtual NIC**, not a productized policy DSL.

Typical operator patterns:

| Mode | Setup | Maps to posture |
|---|---|---|
| Air-gapped guest | No network interface configured | Strong local / no egress |
| Host-only | TAP to host bridge without default route / MASQUERADE | Local tools via host proxy only |
| Allowlisted egress | TAP + host nftables/iptables allowlist (or CNI NetworkPolicy-like rules) | Vendor APIs only through approved channels |
| Open | NAT to host uplink | Only when Spec Input allows broad egress |

**Egress budget** (contract language) is implementable via Firecracker’s
**virtio rate limiters** (bytes/sec and ops/sec on net devices) plus
adapter-side accounting. That is closer to a true budget knob than
Modal’s block/allowlist-only model — but the Adapter owns the mapping
from Orchestrator “egress budget” to limiter parameters.

**Tool Transport bridge:** prefer **vsock** (or a host agent listening
on a host-only path) so Dev Products do not need a general internet
path to reach MCP/tool endpoints. MMDS can carry bootstrap config
without baking secrets into the rootfs.

---

## Lifecycle mapping (Orchestrator → Sandbox → Audit)

```text
Orchestrator dispatches sub-task
        │
        ▼
Adapter prepares:
  - unique id, jail root under chroot-base
  - rootfs image (clone COW/overlay or fresh disk)
  - optional data disk for workspace
  - netns + TAP + firewall rules for posture
  - place kernel + disks into jail (hardlink/copy)
        │
        ▼
jailer --id … --exec-file firecracker --uid … --gid … --netns … --cgroup …
        │  audit: sandbox.created {id, task_id, posture, host}
        ▼
API / config-file: boot-source, drives, network-interfaces, rate limiters
InstanceStart
        │
        ▼
Wait for ready (serial marker, vsock hello, or guest agent)
Inject or mount workspace; run Dev Product command
        │
        ▼
Collect artifacts (pull from data disk / vsock / shared volume)
        │
        ▼
Graceful guest shutdown or SIGTERM Firecracker; cleanup jail, TAP, netns
        │  audit: sandbox.finished {id, exit, duration, resource_use}
```

**Wall clock:** Adapter must enforce Orchestrator timeout; Firecracker has no
Modal-style `idle_timeout` product feature — implement with host timer.

**Snapshot path:** for multi-turn agents, boot once → warm snapshot →
restore per sub-task (tens of ms class restores reported in community
write-ups; verify on target hardware). Default pattern remains
ephemeral destroy-after-task unless `state_persistence` is declared.

---

## Host prerequisites and ops burden

| Requirement | Detail |
|---|---|
| KVM | `/dev/kvm` present; hardware virt enabled |
| Privileges | Jailer typically started as root; drops to configured uid/gid |
| Kernel + rootfs pipeline | Uncompressed guest kernel; ext4 (or supported) rootfs with Dev Product toolchain |
| Networking glue | TAP, bridges, IPAM, NAT/allowlists — or CNI via firecracker-containerd |
| Density | Low VMM overhead; host RAM/CPU still bound concurrency |
| Nested virtualization | Often unavailable or slow in nested VMs; prefer bare metal or KVM-friendly hosts |
| Observability | Firecracker log/metrics pipes; guest-level logs need serial/vsock capture |
| Cleanup | Operator responsibility (cgroup notify, adapter reaper); easy to leak jails/TAPs if Adapter is sloppy |

**Ops burden is the main trade-off vs Modal:** isolation and locality
are excellent; you own the fleet, images, networking, and failure modes.

---

## GPU and related non-goals

Firecracker’s minimal device model **excludes GPU passthrough**.
Project and industry sources consistently treat this as intentional.

Implications for EposForge:

- `gpu_support: false` on a pure Firecracker Execution Sandbox Adapter.
- GPU-accelerated Dev Products need a **different** sandbox Adapter
  (Docker/K8s + NVIDIA toolkit, Cloud Hypervisor, QEMU, or a hosted
  GPU sandbox such as Modal).
- Do not plan “one Firecracker adapter for all dispatches” if the
  factory mix includes GPU work — multi-adapter routing by capability.

Related stacks (not Firecracker itself):

| Stack | Role |
|---|---|
| **firecracker-containerd** | OCI/containerd integration; CNI networking; multi-container-in-VM patterns |
| **Kata Containers (Firecracker hypervisor)** | Kubernetes RuntimeClass path to microVMs |
| **Cloud Hypervisor** | Peer microVMM; often chosen when PCIe/GPU passthrough is required |
| **Hosted Firecracker platforms** (e.g. agent sandbox vendors) | Operator buys isolation as a service; privacy becomes vendor unless self-hosted |

An EposForge Adapter might wrap raw Firecracker **or** one of these
orchestrators; metadata should name the actual isolation path.

---

## Isolation comparison (catalog peers)

| Candidate | Isolation | Egress control | Local privacy | Ops burden | Burst scale | GPU |
|---|---|---|---|---|---|---|
| Docker containers | namespaces + cgroups | good (self-managed) | yes | low | host-bound | yes (toolkit) |
| K8s ephemeral pods | + NetworkPolicy / multi-host | strong | yes (private cluster) | medium–high | cluster-bound | yes |
| **Firecracker** | **KVM microVM + jailer** | **strong if host-wired** | **yes** | **high** | host-bound | **no** |
| OpenClaw | containerized gateway + browser | per-instance | yes | medium | host-bound | rare |
| Modal Sandboxes | gVisor (+ VM option) | strong API-native | **no** | low (vendor) | very high | yes (gVisor path) |

**Rule of thumb:**

- Need **local + strongest isolation + untrusted code** → Firecracker
  (or Kata/Firecracker on K8s).
- Need **elastic concurrency without fleet ops + vendor privacy OK** →
  Modal (or similar).
- Need **GPU agents on self-host** → not pure Firecracker.
- Need **simple local floor** → Docker.

---

## Gaps and adapter design risks

1. **Not a turnkey sandbox product** — rootfs, net, jail, artifact I/O,
   and lifecycle are Adapter (or intermediate platform) work. Underestimate
   at your peril; “just use Firecracker” is incomplete advice.

2. **Network policy is external** — unlike Modal’s
   `block_network` / domain allowlists, policy lives in host netns and
   firewall. Bugs here silently weaken `privacy: local`.

3. **No GPU** — hard capability gap; route GPU sub-tasks elsewhere.

4. **Image supply chain** — guest kernels and rootfs images must be
   built, versioned, patched, and attested. Treat rootfs like a Living
   Spec artifact for the sandbox Adapter.

5. **Privilege boundary** — jailer starts privileged; Adapter host
   process that can launch jails is high trust. Protect the control
   path (who may create microVMs) as carefully as Secrets.

6. **Cleanup races** — leaked TAP devices, netns, jail directories, and
   cgroups accumulate. Need a reaper and idempotent destroy.

7. **Nested virt / cloud VMs** — many cloud VM types lack usable KVM;
   Firecracker often wants metal or nested-virt-enabled shapes. Substrate
   choice is part of Platform Factory design.

8. **Browser / GUI** — not provided; headless browser means installing
   into rootfs and accepting size/boot cost (or a specialized peer
   Adapter like OpenClaw).

9. **Audit completeness** — raw Firecracker logs are not Audit &
   Observability. Adapter must emit normative events and correlate
   `task_id` / Spec Input ids.

10. **Snapshot security** — memory snapshots can contain secrets and
    agent state; store and TTL them under Secrets/policy, similar to
    Modal snapshot hygiene concerns.

---

## When Firecracker is a good Execution Sandbox choice

Use / shortlist Firecracker when **most** of the following hold:

- Workloads include **untrusted** or high-blast-radius Dev Product code.
- **`privacy: local`** (or strict data locality) is required.
- Operator can run **KVM-capable hosts** and invest in image + net glue.
- GPU is **not** required for those dispatches (or GPU uses another
  Adapter).
- Density of short-lived sandboxes on a host matters (serverless-like
  packing).

Prefer **not** pure Firecracker when:

- Team cannot staff microVM operations (prefer Docker or hosted sandbox).
- Primary need is browser-native agent UX (evaluate OpenClaw-class tools).
- Sub-tasks need GPUs.
- Burst to tens of thousands of concurrent sandboxes without owning
  capacity (evaluate hosted options).

---

## Sketch: Adapter responsibilities

Normative contract lives in the component doc; this is research only.

1. **Preflight host** — KVM available; cgroup v1/v2 layout understood;
   jailer + firecracker binaries version-pinned and checksummed.
2. **Map Orchestrator resource hints** → vCPU, mem, jailer cgroups, virtio
   rate limiters, wall-clock timer.
3. **Map privacy / network policy** → no-NIC / isolated netns /
   allowlist firewall; refuse if host cannot enforce requested posture.
4. **Materialize rootfs** — from versioned base images; inject only
   non-secret bootstrap; secrets via MMDS/vsock from Secrets slot at
   runtime.
5. **Start via jailer** — never production-default to un-jailed VMM.
6. **Run Dev Product** — guest agent or SSH-over-vsock/serial; stream
   logs to Audit.
7. **Collect artifacts** — pull from data disk or vsock; hand off to
   Source Control + CI or agreed return path.
8. **Destroy** — stop VMM, delete jail tree, release TAP/netns/cgroup;
   emit finished audit event with resource usage.

Optional: snapshot warm pool; firecracker-containerd for OCI ergonomics;
Kata RuntimeClass when the factory already lives on Kubernetes.

---

## Secondary notes (non-slot or adjacent)

| Topic | Assessment |
|---|---|
| Inference Layer | Firecracker is not an inference product. You *could* run a local model **inside** a microVM for isolation, but the Inference Adapter would still be Ollama/vLLM/etc.; Firecracker would be the Execution Sandbox underneath, not the Inference slot filler. |
| Platform Factory substrate | MicroVM hosts are a substrate choice (metal + KVM). Fits “containers → multi-host → GPU nodes” ladder as a **security-hardened runtime**, not a replacement for orchestration. |
| Hosted Firecracker (Lambda MicroVMs, etc.) | Vendor-operated Firecracker moves privacy posture to `vendor`; treat as a different Adapter with cloud locality. |

---

## Recommendation

| Decision | Guidance |
|---|---|
| Pattern change needed? | **No** |
| Primary slot | **Execution Sandbox** |
| Catalog action | Expand Firecracker entry; link this deep-dive (done alongside this note) |
| Implementation priority | **Medium for local-first / untrusted-code factories**; **low** if the instance is vendor-sandbox-first or GPU-heavy |
| Best paired with | Docker (floor) and/or Modal (burst vendor) as sibling Adapters; Orchestrator selects by privacy + gpu_support + isolation strength |
| Next engineering step if pursued | Spike: jailer-booted microVM → isolated netns → run a Dev Product CLI → artifact out → destroy; measure boot/snapshot latency and failure cleanup on the actual host class |

---

## Sources (primary)

- https://firecracker-microvm.github.io/
- https://github.com/firecracker-microvm/firecracker
- https://github.com/firecracker-microvm/firecracker/blob/main/docs/getting-started.md
- https://github.com/firecracker-microvm/firecracker/blob/main/docs/jailer.md
- https://github.com/firecracker-microvm/firecracker/blob/main/SPECIFICATION.md
- https://github.com/firecracker-microvm/firecracker/blob/main/docs/snapshotting/snapshot-support.md
- Related: firecracker-containerd, Kata Containers Firecracker support
- EposForge contract: `01-architecture/02-components/execution-sandbox.md`
- Peer catalog / Modal deep-dive under this folder

---

## Contribution / refresh

When upstream changes SLA numbers, device model, snapshot APIs, or
GPU-related roadmap items, update this note and the catalog entry
together. Prefer measuring boot and restore times on the target host
class rather than relying solely on published 125 ms / community
restore figures.

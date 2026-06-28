---
doc_kind: architecture-concept
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Autonomy Modes

## Purpose

EposForge factories operate at a declared **autonomy mode**. The mode is
not a different architecture — it is the same component set with a
different degree of human presence in the execution loop. A factory
instance declares its current `autonomy_mode`; the mode determines how
the Router dispatches, how secrets are bound, and what each Dev Product
Adapter is permitted to do.

The modes form a progression. The dark factory (`autonomous`) is the end
state; `supervised` is not throwaway scaffolding — it is how an instance
*earns* the trust calibration that makes `autonomous` safe. Per-step
manual approval ("human-in-the-loop") is the pre-EposForge baseline this
pattern supersedes; it is not a factory mode.

## The spectrum

| Mode | Human role | Manufacturing analogue |
|---|---|---|
| `supervised` | **On the loop** — observes a near-autonomous fleet; intervenes by exception. | Lights-on automated factory; supervisors on the floor. |
| `autonomous` | **Off the loop** — no human present in the critical path. | Dark (lights-off) factory. |

## The ToS threshold

The line between `supervised` and `autonomous` is not only technical — it
is contractual, and it is the gating constraint for several Dev Products.

Subscription / OAuth-authenticated products (Claude Code, Gemini CLI,
GitHub Copilot) are sanctioned by their vendors for **human-present** use
inside their own client, but their terms restrict automated / non-human
access. Concretely (verified May 2026):

- **Anthropic** — OAuth subscription tokens (Free/Pro/Max) are permitted
  *inside Claude Code / claude.ai*; an **API key is required** for Agent
  SDK / unattended automation.
  ([consumer terms](https://www.anthropic.com/legal/consumer-terms),
  eff. 2025-10-08; clarification
  [The Register, 2026-02-20](https://www.theregister.com/software/2026/02/20/anthropic-clarifies-ban-on-third-party-tool-access-to-claude/5014546))
- **Google Gemini CLI** — OAuth use in third-party / automated wrappers
  has drawn 403 enforcement; direct API keys are the supported automation
  path.
- **GitHub Copilot** — acceptable-use terms restrict bulk / automated
  activity; `--allow-all-tools` exists but is warned against for
  unattended use.

**Consequence:** these products are usable through `supervised` mode on
their subscription auth, but moving them into `autonomous` mode requires
re-binding to BYOK / API-key auth. OSS BYOK products (Aider, OpenCode,
Continue.dev, OpenAI Codex CLI, Goose, OpenHands) carry no such threshold.

## Per-mode component implications

| Component | `supervised` | `autonomous` |
|---|---|---|
| **4 Router** | IDE-native fleet manager (VS Code agents, Cursor background agents) may serve as Router. | Own headless Router required. |
| **11 Audit & Observability** | **Required, live** — the supervision surface. | Required for forensics. |
| **8 Agent Policy** | Permissive-but-bounded, human as backstop; **policy is calibrated here**. | Calibrated policy enforced headlessly. |
| **7 Execution Sandbox** | Recommended; human backstop tolerates lighter isolation. | Required. |
| **3 Dev Product (auth)** | Subscription / OAuth permitted. | **BYOK / API-key required** for ToS-restricted products. |

## New Adapter metadata field

Dev Product Adapters declare the highest mode their licensing / ToS
permits, as a threshold rather than a binary (see
[02-components/dev-product.md](../02-components/dev-product.md)):

- `autonomy_tos_posture: byok-clean-all-modes`
  (aider, opencode, continue, codex-cli, goose, openhands)
- `autonomy_tos_posture: subscription-ok-through-supervised; api-key-required-for-autonomous`
  (claude-code, gemini-cli) — a BYOK / API-key rebind unlocks `autonomous`.
- `autonomy_tos_posture: subscription-only; supervised-max`
  (copilot) — no BYOK path and no sanctioned headless surface, so it
  cannot be promoted to `autonomous` regardless of rebind.

## Progression contract

`supervised` is the calibration ground for `autonomous`: an instance may
not promote a Dev Product from `supervised` to `autonomous` until its
observed behavior under supervision justifies the auto-grant profile the
headless Agent Policy ([02-components/agent-policy.md](../02-components/agent-policy.md))
will enforce. Promotion is evidence-based, not scheduled.

## Two loops: autonomy vs self-detection

Autonomy promotion is easy to conflate with a second, independent activity
the factory performs on itself. Keep them apart — confusing them produces
the false dilemma *"do I demote this component or invest in it?"*

- **Loop A — autonomy.** The factory autonomously drains its backlog:
  builds products, fixes itself. This is the end state, and *trusting* it
  is governed by the **bootstrap order** in
  [stabilization-and-kernels.md](../04-stabilization-and-kernels/stabilization-and-kernels.md#the-bootstrap-rule):
  a layer's Loop-A autonomy is trusted only once the layers beneath it are
  kernels.
- **Loop B — self-detection.** The factory hardens *its own operating
  configuration* — adds smoke gates, one-command restarts, reconstruction
  checks. This is how a component **becomes** a kernel.

**The bootstrap order governs Loop A (trusting autonomy), not Loop B
(adding detection).** Loop B is valid work on *any* layer right now —
including layers whose autonomy you will not trust until the layers under
them are solid. This asymmetry dissolves the apparent contradiction of
hardening a component while withholding trust in its autonomy: you harden
it *by hand* (Loop B) precisely so that, when its autonomy is eventually
trusted (Loop A), it cannot silently break itself. A component can be a
*candidate kernel* worth Loop-B investment and simultaneously a component
whose Loop-A autonomy stays off — those are not in tension.

The detection minted in Loop B is the subject of the
[09-paired-detection](../../04-standards/09-paired-detection/paired-detection.md)
standard.

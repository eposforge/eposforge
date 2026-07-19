---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Dev Products — Implementation Catalog

> **Snapshot date:** 2026-05. Pricing, features, and privacy postures
> change frequently. Verify current details before installing.

Candidate Adapters for the Dev Product slot
([../../01-architecture/02-components/dev-product.md](../../01-architecture/02-components/dev-product.md)).
A Dev Product accepts a sub-task descriptor from the Router and
produces artifacts. Many products listed here can plug into the slot
once an Adapter exists for them.

This catalog is **not exhaustive** and **not an endorsement**. Use it
as a starting point for evaluation.

The 2026-05 pass added two axes — **BYOK** and **Autonomy / ToS
posture** — to the directly-installable dev tools (CLI agents and
AI-native IDEs). These two axes are gating for the dark factory: a
product can be technically headless yet contractually barred from
running unattended. See
[../../01-architecture/03-autonomy-modes/autonomy-modes.md](../../01-architecture/03-autonomy-modes/autonomy-modes.md)
for the mode spectrum and the ToS threshold. Enterprise-platform
entries below were not re-scored on these axes in this pass.

---

## How to read this catalog

Each entry includes (where known):

- **Type** — IDE extension, CLI / terminal agent, IDE, framework.
- **Cost tier** — free-OSS, consumer-paid, commercial.
- **Privacy posture** — `local`, `vendor-no-training`, or
  `vendor-default` (best-effort summary; verify with the vendor).
- **Capabilities** — what task shapes it tends to handle well.
- **BYOK** — whether you can bring your own model API key (or run a
  local model), versus being locked to a vendor subscription / seat /
  token plan. Bears directly on per-task fan-out economics.
- **Autonomy / ToS** — the highest autonomy mode the product's terms
  and invocation surface permit (`byok-clean-all-modes`,
  `subscription-ok-through-supervised; api-key-required-for-autonomous`,
  `supervised-max`, etc.). See
  [../../01-architecture/03-autonomy-modes/autonomy-modes.md](../../01-architecture/03-autonomy-modes/autonomy-modes.md).
- **Notes** — anything notable for Adapter authors.

A product is a strong Dev Product candidate if it:

- Accepts a structured task instruction.
- Can edit multiple files / interact with shell, browser, or git.
- Returns a usable artifact (PR, patch, file set).
- Has a stable invocation surface (CLI, library, IDE protocol, etc.).

A strong **dark-factory** (`autonomous`-mode) candidate additionally:

- Runs headless / non-interactively (one-shot prompt, SDK, CI).
- Carries no ToS bar on unattended / automated use (BYOK / API-key
  auth, or a permissive OSS license).
- Can be sandboxed and can emit structured audit events.

---

## Candidates

### GitHub Copilot (IDE extension)

- **Type:** IDE extension (VS Code, JetBrains, others).
- **Cost tier:** consumer-paid (free tier available).
- **Privacy posture:** business / enterprise plans avoid training on
  customer data; consumer plans require opt-out.
- **Capabilities:** inline autocomplete, chat, agent mode (recent),
  multi-file edits.
- **BYOK:** no — per-seat Copilot subscription; no own-key path.
- **Autonomy / ToS:** `supervised-max`. IDE-extension surface has no
  sanctioned headless mode, and GitHub's acceptable-use policy restricts
  bulk / automated activity. Cannot reach `autonomous`.
- **Notes:** broad reach; works inside an existing editor. Good
  operator / glass-cockpit surface, not an unattended worker. For the
  terminal product, see **GitHub Copilot CLI** below.

### GitHub Copilot CLI

- **Type:** CLI / terminal agent (GA 2026-02).
- **Cost tier:** consumer-paid (Copilot subscription).
- **Privacy posture:** follows Copilot plan posture (business /
  enterprise no-training; consumer opt-out).
- **Capabilities:** terminal-native agent; `-p` / `--prompt` one-shot,
  autopilot mode, `--allow-all-tools`; ships the GitHub MCP server by
  default plus custom MCP config.
- **BYOK:** no — bound to the Copilot subscription; automation uses
  env-var GitHub tokens (`COPILOT_GITHUB_TOKEN` / `GH_TOKEN` /
  `GITHUB_TOKEN`), not an arbitrary model key.
- **Autonomy / ToS:** technically headless, but GitHub's acceptable-use
  policy restricts bulk / automated activity and there are community
  reports of suspensions for scripted use. Treat as
  `subscription-ok-through-supervised` until the AUP position on
  unattended CLI use is clarified; do not assume `autonomous`.
- **Notes:** materially different product from the IDE extension. The
  strongest Copilot-family dark-factory candidate, gated by the AUP
  question rather than by capability.

### Cursor

- **Type:** AI-native IDE (with a headless CLI).
- **Cost tier:** consumer-paid (subscription + credits).
- **Privacy posture:** model-dependent; no unique privacy layer.
- **Capabilities:** Composer multi-file edits, agent / background
  agents, terminal ops; dedicated CLI for automation / CI.
- **BYOK:** partial — primarily vendor models / credits; some own-key
  support.
- **Autonomy / ToS:** no explicit ban on headless use, but the
  subscription / credit economics fight high-concurrency fan-out, and
  the terms carry auto-execution risk disclaimers. Best fit as a
  `supervised`-mode operator surface; weak for `autonomous` economics.
- **Notes:** strongest "watch a fleet of agents" UX for the supervised
  intermediate; its background-agents view can serve as a temporary
  Router in `supervised` mode.

### Claude Code

- **Type:** CLI / terminal agent.
- **Cost tier:** consumer-paid (Pro / Max tiers) or API-key.
- **Privacy posture:** commercial / enterprise default no training;
  consumer opt-out.
- **Capabilities:** deep reasoning, multi-step agentic autonomy, file
  ops, terminal ops, browser ops via integrations; headless `-p` /
  Agent SDK.
- **BYOK:** yes — point it at an Anthropic API key.
- **Autonomy / ToS:**
  `subscription-ok-through-supervised; api-key-required-for-autonomous`.
  Anthropic permits OAuth subscription tokens (Free/Pro/Max) only for
  human-present use inside Claude Code / claude.ai; an API key is
  required for Agent SDK / unattended automation. See the landmines
  section.
- **Notes:** strong for headless and CI-driven invocations once rebound
  to an API key.

### OpenAI Codex

- **Type:** CLI + web/app + IDE integration.
- **Cost tier:** bundled with ChatGPT plans, or API-key.
- **Privacy posture:** vendor-default; opt-out available.
- **Capabilities:** fast execution, sandboxed runs, async tasks.
- **BYOK:** yes — uses your OpenAI API key.
- **Autonomy / ToS:** `byok-clean-for-automation`. The API is designed
  for programmatic use; no notable consumer restriction on CLI
  automation reported.
- **Notes:** good for parallel async sub-task fan-out.

### Gemini CLI

- **Type:** CLI / terminal agent (OSS, Apache-2.0 client).
- **Cost tier:** free + consumer-paid tiers, or API-key.
- **Privacy posture:** free tier may train on data; paid tiers
  generally do not.
- **Capabilities:** very large context windows, fast, low cost;
  MCP extension ecosystem (install any MCP server and Gemini CLI
  consumes it).
- **BYOK:** yes — Vertex AI / AI Studio API key; free tier uses Google
  account OAuth.
- **Autonomy / ToS:**
  `oauth-ok-through-supervised; api-key-required-for-autonomous`. Google
  enforces against OAuth use in automated / third-party-wrapper patterns
  (403s, account disables); direct API keys are the supported automation
  path. See the landmines section.
- **Notes:** strong for large-codebase ingestion tasks. When
  paired with the Neo4j MCP extension (Tool Transport slot), gains
  live read/write access to the Spec Graph; operators can issue
  natural-language consistency checks and spec-generation commands
  against the full knowledge graph. See
  [../spec-graph/graphrag-neo4j-integration.md](../spec-graph/graphrag-neo4j-integration.md)
  for the recommended pipeline. Reference Dev Product for the
  GraphRAG + Neo4j integration pattern, though any MCP-compatible
  Dev Product (Claude Code, Cursor, Goose, OpenCode) is a drop-in
  substitute at the Tool Transport layer.

### Aider

- **Type:** open-source CLI.
- **Cost tier:** free OSS (operator brings own model API keys).
- **Privacy posture:** depends on chosen model; supports local models
  (e.g., Ollama).
- **Capabilities:** git-native (auto-commits), multi-file edits,
  flexible model choice.
- **BYOK:** yes — any provider, including fully local.
- **Autonomy / ToS:** `byok-clean-all-modes` (Apache-2.0; only the
  chosen model provider's ToS applies).
- **Notes:** clean Adapter target — well-defined CLI, clear i/o; gold
  standard for git-native scripting / CI.

### Continue.dev

- **Type:** open-source IDE extension + headless CLI (`cn -p`).
- **Cost tier:** free OSS core.
- **Privacy posture:** depends on chosen LLM; local models for
  strongest privacy.
- **Capabilities:** multi-model, customizable, IDE-integrated; headless
  CLI mode for scripting / CI.
- **BYOK:** yes — fully own-key + local.
- **Autonomy / ToS:** `byok-clean-all-modes`.
- **Notes:** Adapter via Continue's plugin protocol or the CLI; more
  rules / checks-oriented than a full autonomous PR generator.

### Goose

- **Type:** open-source CLI + desktop.
- **Cost tier:** free OSS.
- **Privacy posture:** strong; supports fully local operation.
- **Capabilities:** general-purpose agent, MCP-extensible.
- **BYOK:** yes — own-key + local models.
- **Autonomy / ToS:** `byok-clean-all-modes` (Apache-2.0).
- **Notes:** good fit for privacy-sensitive sub-tasks; still maturing as
  a dedicated coding harness vs. broader agent use.

### OpenCode

- **Type:** open-source CLI + tools.
- **Cost tier:** free OSS core.
- **Privacy posture:** privacy-first by default.
- **Capabilities:** large-repo support, many provider integrations.
- **BYOK:** yes — 75+ providers.
- **Autonomy / ToS:** `byok-clean-all-modes`.
- **Notes:** broad provider support good for cost-tier flexibility;
  fast-moving project, verify stability on very large repos.

### OpenHands

- **Type:** open-source agent (formerly OpenDevin lineage).
- **Cost tier:** free OSS.
- **Privacy posture:** local / private via Docker / Ollama.
- **Capabilities:** autonomous greenfield development, production
  deployment workflows.
- **BYOK:** yes — own-key + local.
- **Autonomy / ToS:** `byok-clean-all-modes` (MIT).
- **Notes:** more autonomous than typical Dev Products; verify
  whether it fits the Dev Product slot or the Router slot in your
  instance.

### Cline

- **Type:** open-source terminal / VS Code agent.
- **Cost tier:** free OSS.
- **Privacy posture:** local; BYOK.
- **Capabilities:** terminal-first, file ops, browsing.
- **BYOK:** yes.
- **Autonomy / ToS:** `byok-clean-all-modes`, but IDE-centric — less
  headless-native than the pure CLIs.
- **Notes:** narrow surface; Adapter is straightforward.

### Windsurf

- **Type:** AI-native IDE.
- **Cost tier:** consumer-paid (subscription).
- **Privacy posture:** provider-dependent.
- **Capabilities:** Cascade agent, codebase understanding, flow-state
  editing.
- **BYOK:** weak — subscription-oriented.
- **Autonomy / ToS:** `supervised-max`. No prominent headless / CLI
  mode; GUI-oriented, human-in-flow design.
- **Notes:** strong supervised-mode editor; not an unattended worker.

### Kiro

- **Type:** spec-driven IDE.
- **Cost tier:** consumer-paid.
- **Privacy posture:** depends on provider.
- **Capabilities:** intent-to-spec-to-tasks workflow.
- **Notes:** may better fit the **Spec Input** slot
  ([../../01-architecture/02-components/spec-input.md](../../01-architecture/02-components/spec-input.md))
  than the Dev Product slot. Listed here for awareness.

### OpenClaw

- **Type:** open-source agent gateway + sandbox browser.
- **Cost tier:** free OSS.
- **Privacy posture:** local; runs entirely inside the operator's
  network.
- **Capabilities:** LLM-driven multi-step browser automation, file
  ops, and shell ops via a sandboxed VNC / noVNC / CDP environment.
- **BYOK:** yes — via the underlying model.
- **Autonomy / ToS:** OSS, no gateway-level restriction. **Caveat:**
  wrapping a ToS-restricted product (e.g. Gemini OAuth, Claude OAuth)
  inside OpenClaw does **not** launder the underlying ToS — automated
  use through a wrapper is exactly what those vendors enforce against.
  The agent dispatched inside it still needs BYOK / API-key auth for
  `autonomous` mode.
- **Notes:** dual-fit — operates as a Dev Product for browser-heavy
  sub-tasks, and is the canonical **Execution Sandbox** in instances
  that adopt it. See
  [execution-sandbox.md](../execution-sandbox/execution-sandbox.md). Adapter must
  declare which slot it fills in a given factory instance.

---

## Code-knowledge-graph / semantic-search layer

These products score strongly on building a queryable graph or semantic
index of a codebase but weakly on autonomous artifact production. They
are **context / retrieval** providers, not Dev Products: in EposForge
terms they feed agents through **Tool Transport (Component 5)** as a
**code-structure** capability (and only loosely as a Spec Graph
complement when Living Specs are also projected — which most do not).
They index **implementation (as-built)**, not Product Living Specs.
Evaluate them as complements to the instance's Spec Graph (e.g. cognee),
not as workers and **not as a replacement** for Component 6.

### Sourcegraph (Cody / Amp)

- **Type:** code-intelligence platform + IDE clients.
- **Cost tier:** enterprise / subscription.
- **Capabilities:** universal code knowledge graph + semantic search,
  API-accessible for context retrieval.
- **BYOK:** model-dependent (enterprise).
- **Autonomy / ToS:** discovery / retrieval layer, not an autonomous
  agent; enterprise team-use terms.
- **Notes:** best-in-class code graph + search; consume via API / MCP as
  a Component-6 / Component-5 provider.

### Augment Code

- **Type:** agent + Context Engine platform.
- **Cost tier:** subscription / enterprise.
- **Capabilities:** real-time semantic KG / dependency graph over
  massive multi-repo codebases (400k+ files).
- **BYOK:** weak — subscription / enterprise.
- **Autonomy / ToS:** agentic but human-in-loop oriented; not a pure
  headless / exportable layer.
- **Notes:** outstanding large-codebase semantic context; weigh as a
  Component-6 alternative / complement to cognee, with vendor lock-in.

### Code-Graph-RAG

- **Type:** open-source knowledge graph tool.
- **Cost tier:** free OSS + model API keys.
- **Privacy posture:** local / BYOK.
- **Capabilities:** Tree-sitter-based code mapping, deep multi-repo
  code context, knowledge graph generation.
- **Notes:** native code knowledge graph via Tree-sitter; strong
  candidate for Tool Transport code-structure Adapters. Not a
  substitute for Living Spec → Spec Graph.

### codebase-memory-mcp (DeusData)

- **Type:** open-source MCP server — structural code intelligence /
  knowledge graph for AI coding agents.
- **Homepage:** https://deusdata.github.io/codebase-memory-mcp/
- **Source:** https://github.com/DeusData/codebase-memory-mcp
- **Cost tier:** free OSS (MIT); no API key for indexing/query.
- **Privacy posture:** `local` — single static C binary; tree-sitter +
  Hybrid LSP + on-device embeddings; code never leaves the machine.
- **Capabilities:** indexes source into a persistent SQLite graph
  (functions, classes, call chains, HTTP routes, cross-service links,
  IaC nodes); 15 MCP tools including `search_graph` (structural +
  semantic), `trace_path`, `detect_changes` (diff blast radius),
  `query_graph` (read-only Cypher), `get_architecture`,
  `get_code_snippet`; auto-sync watcher; optional team graph artifact
  (`.codebase-memory/graph.db.zst`); 158 languages; multi-repo
  `CROSS_*` edges.
- **BYOK:** N/A for graph engine (no embedded LLM); agent client
  supplies NL→tool translation.
- **Autonomy / ToS:** retrieval/structure backend only; not a Dev
  Product. Installer configures many agent surfaces (Claude Code,
  Cursor, Codex, Goose, etc.).
- **Notes:** Strong OSS peer to Sourcegraph-class code graphs with zero
  infra. **Tool Transport** code-structure provider. Must not ingest
  into or replace Cognee/Spec Graph Living Spec projections. Prefer
  for call paths, impact, dead code, route maps; prefer Spec Graph for
  product intent / factory architecture. Research snapshot: 2026-07
  (v0.8.x).

---

## Enterprise / platform candidates

> Not re-scored on the BYOK / autonomy axes in the 2026-05 pass. Most
> are full platforms that would host a Dev Product Adapter internally
> rather than install directly into the slot.

### Blitzy

- **Type:** enterprise platform (agentic engineer).
- **Cost tier:** enterprise (est. $50k evaluation / $500k/yr).
- **Privacy posture:** private; focuses on secure enterprise ingestion.
- **Capabilities:** GraphRAG core, legacy code mapping, Technical Specs
  generation.
- **Notes:** full-platform candidate; not typically installed directly
  into the Dev Product slot. May host a Dev Product Adapter internally.
  Native GraphRAG for full-system knowledge mapping suits large
  enterprise legacy-replacement programs.

### Graph-Code

- **Type:** agentic IDE / platform.
- **Cost tier:** commercial (est. $10k–$50k/yr, usage-based tiers).
- **Privacy posture:** private; graph-based logic stays on the vendor
  platform.
- **Capabilities:** multi-repo mapping, Docker/K8s automation, native
  multi-repo graph mapping & RAG.
- **Notes:** knowledge-graph-native design; a strong candidate where
  graph-aware Dev Product Adapters are required.

### Harness AIDA

- **Type:** enterprise DevOps platform.
- **Cost tier:** commercial ($50–$150/dev/mo; free tier for small
  teams).
- **Privacy posture:** commercial / enterprise standards.
- **Capabilities:** pipeline automation, built-in knowledge graph RAG,
  compliance tooling.
- **Notes:** full-platform candidate; may host a Dev Product Adapter
  internally rather than filling the slot directly. Best fit for
  enterprise DevOps and compliance workflows.

### StackGen

- **Type:** autonomous ops platform.
- **Cost tier:** enterprise (est. $100k+; limited trial).
- **Privacy posture:** enterprise-grade isolation.
- **Capabilities:** intent-based infrastructure management, autonomous
  remediation, graph-backed intent & remediation engine.
- **Notes:** graph-backed ops focus; better suited to
  infrastructure/ops sub-tasks than typical code-generation Dev
  Product tasks.

### Autonomy AI

- **Type:** agentic workflow platform.
- **Cost tier:** commercial ($125–$999+/mo, tiered by usage).
- **Privacy posture:** departmental isolation.
- **Capabilities:** ACE engine, custom internal agents, graph workflow
  orchestration.
- **Notes:** full-platform candidate for building org-specific internal
  tools; not typically installed directly into the Dev Product slot.

### Microsoft Agent Framework

- **Type:** open-source multi-agent framework (successor to AutoGen).
- **Cost tier:** free OSS + model API keys.
- **Privacy posture:** local deployment / private cloud.
- **Capabilities:** conversable agents, multi-agent orchestration,
  graph management & sync.
- **Notes:** primarily a Router candidate; can also dispatch in ways
  that resemble a Dev Product for some tasks. See router research for
  the primary evaluation.

### Kagent

- **Type:** open-source Kubernetes agent.
- **Cost tier:** free OSS (Apache 2.0) + model API keys.
- **Privacy posture:** local infrastructure control.
- **Capabilities:** K8s troubleshooting, security analysis, extendable
  to K8s resource graphs.
- **Notes:** infra-focused; good Adapter target for DevOps and
  Kubernetes management sub-tasks.

---

## ToS / autonomy landmines

Products whose terms or invocation surface restrict autonomous /
headless / automated operation. These gate `autonomous` mode (see
[../../01-architecture/03-autonomy-modes/autonomy-modes.md](../../01-architecture/03-autonomy-modes/autonomy-modes.md)).
This space evolves rapidly — verify the live ToS before relying on any
entry.

- **Anthropic (Claude Code, consumer plans)** — automated / non-human
  access is prohibited except via an Anthropic API key. OAuth
  subscription tokens (Free/Pro/Max) are sanctioned only inside Claude
  Code / claude.ai (human-present); the Agent SDK / unattended
  automation requires an API key.
  ([consumer terms](https://www.anthropic.com/legal/consumer-terms),
  eff. 2025-10-08;
  [The Register, 2026-02-20](https://www.theregister.com/software/2026/02/20/anthropic-clarifies-ban-on-third-party-tool-access-to-claude/5014546))
- **Google Gemini CLI** — OAuth use in third-party wrappers / automated
  patterns has drawn 403 enforcement and account disables; direct API
  keys are the supported automation path. Client is Apache-2.0 but the
  underlying service is governed by Google's ToS.
  ([gemini-cli discussion #22970, 2026-03-18](https://github.com/google-gemini/gemini-cli/discussions/22970);
  [geminicli.com ToS notes, 2026-04-10](https://geminicli.com/docs/resources/tos-privacy/))
- **GitHub Copilot (IDE + CLI)** — acceptable-use policy restricts
  bulk / automated activity; `--allow-all-tools` exists for the CLI but
  is warned against for unattended use, and there are community reports
  of suspensions for scripted use.
  ([GitHub AUP](https://docs.github.com/site-policy/acceptable-use-policies/github-acceptable-use-policies);
  [Copilot CLI docs](https://docs.github.com/copilot/concepts/agents/about-copilot-cli))
- **Cursor** — no blanket ban on headless use, but auto-code-execution
  risk disclaimers in the terms and per-seat / credit economics
  constrain unattended fan-out.
  ([Cursor ToS](https://cursor.com/terms-of-service), eff. 2026-01-13)

OSS BYOK products (Aider, OpenCode, Continue.dev, OpenAI Codex CLI with
own key, Goose, OpenHands, Cline) carry no such bar — only the chosen
model provider's ToS applies.

---

## Likely component cross-overs

Some products have full entries above but primarily fit a different
factory slot:

In hierarchical orchestration mode, these products typically act as
delegated workers in the Dev Product slot unless the operator
explicitly installs one as the Router.

- **Sourcegraph (Cody/Amp), Augment Code, Code-Graph-RAG,
  codebase-memory-mcp** are context / retrieval providers — primarily
  **Tool Transport (Component 5)** code-structure (and only secondarily
  a Spec Graph complement if specs are projected into them). They feed
  agents rather than producing artifacts; they do not replace Living
  Spec → Spec Graph.
- **Microsoft Agent Framework** is primarily a Router candidate; it
  can also dispatch in ways that resemble a Dev Product for some tasks.
- **Blitzy / Harness AIDA / Autonomy AI** are full-platform candidates;
  they could host a Dev Product Adapter internally but would not
  themselves install into the slot.
- **StackGen** is an autonomous ops platform; better suited to
  infrastructure/ops sub-tasks than code-generation work.
- **Kiro** may fit **Spec Input** better than Dev Product.

When an Adapter could fit multiple slots, the operator declares which
slot it fills in their instance.

---

## Contribution

Open a PR adding new entries with the same fields. Prefer products
with stable invocation surfaces and clear privacy postures. If a
product's status changes materially, update its entry rather than
adding a duplicate.

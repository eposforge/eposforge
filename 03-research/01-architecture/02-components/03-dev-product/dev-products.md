---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Dev Products — Implementation Catalog

> **Snapshot date:** 2026-04. Pricing, features, and privacy postures
> change frequently. Verify current details before installing.

Candidate Adapters for the Dev Product slot
([../../01-architecture/02-components/03-dev-product.md](../../01-architecture/02-components/03-dev-product.md)).
A Dev Product accepts a sub-task descriptor from the Router and
produces artifacts. Many products listed here can plug into the slot
once an Adapter exists for them.

This catalog is **not exhaustive** and **not an endorsement**. Use it
as a starting point for evaluation.

---

## How to read this catalog

Each entry includes (where known):

- **Type** — IDE extension, CLI / terminal agent, IDE, framework.
- **Cost tier** — free-OSS, consumer-paid, commercial.
- **Privacy posture** — `local`, `vendor-no-training`, or
  `vendor-default` (best-effort summary; verify with the vendor).
- **Capabilities** — what task shapes it tends to handle well.
- **Notes** — anything notable for Adapter authors.

A product is a strong Dev Product candidate if it:

- Accepts a structured task instruction.
- Can edit multiple files / interact with shell, browser, or git.
- Returns a usable artifact (PR, patch, file set).
- Has a stable invocation surface (CLI, library, IDE protocol, etc.).

---

## Candidates

### GitHub Copilot

- **Type:** IDE extension (VS Code, JetBrains, others).
- **Cost tier:** consumer-paid (free tier available).
- **Privacy posture:** business / enterprise plans avoid training on
  customer data; consumer plans require opt-out.
- **Capabilities:** inline autocomplete, chat, agent mode (recent),
  multi-file edits.
- **Notes:** broad reach; works inside an existing editor. Adapter
  must mediate IDE invocation, since CLI invocation is limited.

### Cursor

- **Type:** AI-native IDE (with CLI).
- **Cost tier:** consumer-paid.
- **Privacy posture:** model-dependent; no unique privacy layer.
- **Capabilities:** Composer multi-file edits, agent mode, terminal
  ops.
- **Notes:** strong IDE experience; Adapter via Cursor's CLI or
  command palette.

### Claude Code

- **Type:** CLI / terminal agent.
- **Cost tier:** consumer-paid (Pro / Max tiers).
- **Privacy posture:** commercial / enterprise default no training;
  consumer opt-out.
- **Capabilities:** deep reasoning, multi-step agentic autonomy, file
  ops, terminal ops, browser ops via integrations.
- **Notes:** strong for headless and CI-driven invocations.

### OpenAI Codex

- **Type:** CLI + web/app + IDE integration.
- **Cost tier:** bundled with ChatGPT plans.
- **Privacy posture:** vendor-default; opt-out available.
- **Capabilities:** fast execution, sandboxed runs, async tasks.
- **Notes:** good for parallel async sub-task fan-out.

### Gemini CLI

- **Type:** CLI / terminal agent.
- **Cost tier:** free + consumer-paid tiers.
- **Privacy posture:** free tier may train on data; paid tiers
  generally do not.
- **Capabilities:** very large context windows, fast, low cost;
  MCP extension ecosystem (install any MCP server and Gemini CLI
  consumes it).
- **Notes:** strong for large-codebase ingestion tasks. When
  paired with the Neo4j MCP extension (Tool Transport slot), gains
  live read/write access to the Spec Graph; operators can issue
  natural-language consistency checks and spec-generation commands
  against the full knowledge graph. See
  [../06-spec-graph/graphrag-neo4j-integration.md](../06-spec-graph/graphrag-neo4j-integration.md)
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
- **Notes:** clean Adapter target — well-defined CLI, clear i/o.

### Continue.dev

- **Type:** open-source IDE extension.
- **Cost tier:** free OSS core.
- **Privacy posture:** depends on chosen LLM; local models for
  strongest privacy.
- **Capabilities:** multi-model, customizable, IDE-integrated.
- **Notes:** Adapter via Continue's plugin protocol.

### Goose

- **Type:** open-source CLI + desktop.
- **Cost tier:** free OSS.
- **Privacy posture:** strong; supports fully local operation.
- **Capabilities:** general-purpose agent, MCP-extensible.
- **Notes:** good fit for privacy-sensitive sub-tasks.

### OpenCode

- **Type:** open-source CLI + tools.
- **Cost tier:** free OSS core.
- **Privacy posture:** privacy-first by default.
- **Capabilities:** large-repo support, many provider integrations.
- **Notes:** broad provider support good for cost-tier flexibility.

### OpenHands

- **Type:** open-source agent (formerly OpenDevin lineage).
- **Cost tier:** free OSS.
- **Privacy posture:** local / private via Docker / Ollama.
- **Capabilities:** autonomous greenfield development, production
  deployment workflows.
- **Notes:** more autonomous than typical Dev Products; verify
  whether it fits the Dev Product slot or the Router slot in your
  instance.

### Cline

- **Type:** open-source terminal agent.
- **Cost tier:** free OSS.
- **Privacy posture:** local; BYOK.
- **Capabilities:** terminal-first, file ops, browsing.
- **Notes:** narrow surface; Adapter is straightforward.

### Kiro

- **Type:** spec-driven IDE.
- **Cost tier:** consumer-paid.
- **Privacy posture:** depends on provider.
- **Capabilities:** intent-to-spec-to-tasks workflow.
- **Notes:** may better fit the **Spec Input** slot
  ([../../01-architecture/02-components/01-spec-input.md](../../01-architecture/02-components/01-spec-input.md))
  than the Dev Product slot. Listed here for awareness.

### OpenClaw

- **Type:** open-source agent gateway + sandbox browser.
- **Cost tier:** free OSS.
- **Privacy posture:** local; runs entirely inside the operator's
  network.
- **Capabilities:** LLM-driven multi-step browser automation, file
  ops, and shell ops via a sandboxed VNC / noVNC / CDP environment.
- **Notes:** dual-fit — operates as a Dev Product for browser-heavy
  sub-tasks, and is the canonical **Execution Sandbox** in instances
  that adopt it. See
  [execution-sandbox.md](../07-execution-sandbox/execution-sandbox.md). Adapter must
  declare which slot it fills in a given factory instance.

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

### Code-Graph-RAG

- **Type:** open-source knowledge graph tool.
- **Cost tier:** free OSS + model API keys.
- **Privacy posture:** local / BYOK.
- **Capabilities:** Tree-sitter-based code mapping, deep multi-repo
  code context, knowledge graph generation.
- **Notes:** native code knowledge graph via Tree-sitter; strong
  candidate for graph-aware Adapters needing deep codebase
  understanding.

---

## Likely component cross-overs

Some products have full entries in the Candidates section above but
primarily fit a different factory slot:

In hierarchical orchestration mode, these products typically act as
delegated workers in the Dev Product slot unless the operator
explicitly installs one as the Router.

- **Microsoft Agent Framework** is primarily a Router candidate; it
  can also dispatch in ways that resemble a Dev Product for some tasks.
- **Blitzy / Harness AIDA / Autonomy AI** are full-platform candidates;
  they could host a Dev Product Adapter internally but would not
  themselves install into the slot.
- **StackGen** is an autonomous ops platform; better suited to
  infrastructure/ops sub-tasks than code-generation work.

When an Adapter could fit multiple slots, the operator declares which
slot it fills in their instance.

---

## Contribution

Open a PR adding new entries with the same fields. Prefer products
with stable invocation surfaces and clear privacy postures. If a
product's status changes materially, update its entry rather than
adding a duplicate.


# Plan: client-side Router v0 — multi-MCP, per-domain, deterministic prompt augmentation

**Scope:** GEA / srv-docker-hp host-local Claude Code config. Internal only — references `grace.lan` hosts; do **not** push to public EposForge.
**Status:** Draft plan, 2026-05-27.
**Backlog:** GEA-004 (instance — this work) · eposforge:EF-013 (Router v0 pattern) · eposforge:EF-011 (recall conflates internal/adopter paths — recall caveat) · eposforge:EF-012 (emits design intent as present state — recall caveat) · eposforge:EF-022 (relocatable `epos-secrets`, for the github PAT).
**Diagrams (same dir):** `cognee-rag-hook-architecture.mmd`, `cognee-rag-hook-flow.mmd`.
**Touches:** `~/.claude/hooks/`, `~/.claude/settings.json`.

---

## 1. Where this fits in EposForge architecture (per cognee Spec Graph)

Prompt augmentation is owned by the **Router (Component 4)**: it augments prompts via retrieval before dispatching to Dev Products. This hook is a **client-side instantiation of Router v0 (EF-013)** — the planned feature for *per-domain gating + deterministic multi-source pre-fetch*. It does not replace the Router; it is the smallest working slice of the Router's augmentation duty, running inside the Claude Code client on srv-docker-hp.

| EposForge component | Role here |
|---|---|
| **Router (C4)** | The hook itself — gates by domain, orchestrates retrieval, injects context. This plan = client-side Router v0. |
| **Tool Transport (C5)** | One Python MCP client that calls adapter tools (http + sse). |
| **Adapters (C5)** | cognee, github, microsoft.docs MCP servers, plugged in behind Tool Transport. |
| **Spec Graph (C6)** | cognee / `eposforge` dataset — the reuse/knowledge source. |

**Recall caveats carried into this shim:** EF-011 (recall conflates EposForge-internal `instance/installed/...` paths with adopter-side infrastructure) and EF-012 (graph emits design intent as present-tense state). Both are *recall-quality* blockers on the full server-side Router; this client shim is usable before they land, but its injected cognee context inherits both. Live example from this design session: the graph asserted a "cognee REST→MCP retirement plan (EF-011)" as present fact — wrong per the authoritative backlog (EF-011 is the conflation bug), a textbook EF-012 symptom.

---

## 2. Problem this solves

`UserPromptSubmit` currently runs `cat ~/.claude/hooks/mcp-routing.md`, injecting a *reminder* to call the right MCP. A text-injection hook cannot **force** a tool call — it relies on the model classifying the domain and choosing to call. That classification keeps missing.

**Fix:** the hook stops reminding and starts **retrieving**. It classifies the prompt's domain(s), calls the matching adapter(s), and injects the *results* as labeled context blocks before the model responds. Retrieval becomes deterministic, multi-source, and auditable — and is no longer the model's decision.

---

## 3. Verified deployment facts (2026-05-27)

- **cognee** — `dkr-cgnee-mcp` (SSE, Up 2d) at `https://cognee-mcp.grace.lan/sse`, proxying `dkr-cgnee-api` (REST, Up 15h healthy, `127.0.0.1:18000`). Dataset `eposforge`. (Graph claims REST is "slated for retirement" — treat as design intent per EF-012, not confirmed fact; unifying on MCP is the safe call regardless.)
- **microsoft.docs** — HTTP MCP at `https://learn.microsoft.com/api/mcp`; tool `microsoft_docs_search` returns ≤10 chunks (≤500 tok each). No auth.
- **github** — HTTP MCP at `https://api.githubcopilot.com/mcp/`; Bearer PAT. Multi-tool interactive surface (`search_code`, `search_issues`, `get_file_contents`, …).
- Hook runs on srv-docker-hp (cdfadmin), same host as the cognee containers.

---

## 4. Transport decision — unify on MCP JSON-RPC

**Recommendation: one Python MCP client (`mcp_retrieve.py`) = client-side Tool Transport (C5).**

Why not per-adapter curl: github and MS Docs are MCP JSON-RPC surfaces (session + `tools/call`), not plain REST. Only cognee has a plain REST search, and that is being retired (EF-011). So the simplicity argument for curl evaporates once there are 3 sources. A single MCP client speaking **http** (github, msdocs) and **sse** (cognee) is cleaner, maps 1:1 to the Adapter pattern, and makes any cognee REST→MCP move a non-event (we're already on MCP).

`mcp_retrieve.py` exposes one primitive: `retrieve(server, tool, args) -> text`, with a per-call timeout and fail-open on any error.

---

## 5. The adapters — per-domain spec (the meat)

Multiple domains may match one prompt → run **all** matched adapters, concatenate labeled blocks, cap per-source and globally. Gate first (cheap, local), then pay network only for matched domains. Run matched adapters **in parallel** (background + wait) to bound latency to ~slowest adapter, not the sum.

| Adapter | Gate — fires when… | Retrieval call (via Tool Transport) | Injected block | Notes |
|---|---|---|---|---|
| **cognee** (Spec Graph) | Topical match: GEA, EposForge, grace.lan, srv-docker-hp, repo names, dev-env/tooling/infra, "this stack" | `search` tool (sse), `eposforge` dataset, `searchType` CHUNKS or GRAPH_COMPLETION, top_k 5 | `<cognee-context>` | Always-relevant source; broadest gate. Inherits EF-011/EF-012 recall-quality caveats. |
| **microsoft.docs** | Topical match: .NET, C#, ASP.NET, Azure, Entra, Microsoft product/API names | `microsoft_docs_search` (http) with the prompt as query, take top 3–4 chunks | `<msdocs-context>` | Clean search→chunks; safe to auto-fire on topical match. |
| **github** | **Entity-triggered only**: explicit `owner/repo` slug, `#<PR>`, issue number, file path, or a named symbol **+** OSS context | Targeted: `search_code` / `search_issues` / `get_file_contents` keyed on the entity; top 3 hits | `<github-context>` | Multi-tool surface — a blind topical search is noisy/expensive. Strict gate: fire only on a concrete entity, never on a vague "github" mention. Needs PAT (vault). |

**Why github's gate is stricter:** cognee and MS Docs have single "search the knowledge → chunks" semantics that map cleanly to deterministic pre-fetch. github does not — it's an interactive tool surface. The only high-value deterministic pre-fetch is "the prompt names a concrete entity, go fetch that entity." Everything else stays model-discretion (the model can still call github tools mid-reasoning).

---

## 6. Architecture

```
UserPromptSubmit
   │ prompt text
   ▼
router.sh  (Router v0 — C4)
   ├─ classify_domains(prompt) → {cognee?, msdocs?, github?}   (cheap, local; github needs entity match)
   ├─ for each matched domain, in parallel:
   │      mcp_retrieve.py <server> <tool> <args>   (Tool Transport — C5; http|sse; per-call timeout; fail-open)
   ├─ collect → label → truncate (per-source cap + global cap)
   └─ print concatenated <…-context> blocks to stdout → injected into model context
residual reminder: only for surfaces NOT auto-retrieved (e.g. HF), kept as a thin nudge
```

---

## 7. Step-by-step implementation

### Phase 0 — Decisions / prereqs
1. **Secrets:** github PAT (and any cognee token) resolved via sops-age / `epos-secrets`, never inlined (`[[reference_sops_age_secrets]]`). See §10 — current tokens are exposed and must be rotated first.
2. Confirm how this Claude Code version passes the prompt to `UserPromptSubmit` (stdin JSON vs env).
3. Confirm an MCP client lib for `mcp_retrieve.py` (Python `mcp` package) can do one-shot `tools/call` over http and sse.
4. Set budgets: per-source token cap (~800–1200), global cap (~2.5k), per-adapter timeout (~4s).

### Phase 1 — Tool Transport
5. Build `~/.claude/hooks/mcp_retrieve.py`: `retrieve(server_url, transport, tool, args, token=None)` → opens a one-shot MCP session, calls the tool, returns text. Fail-open: any error → empty string, exit clean. Per-call timeout enforced.
6. Test each adapter in isolation from the CLI:
   - cognee `search` (sse) → returns eposforge chunks.
   - `microsoft_docs_search` (http) → returns doc chunks.
   - github `search_code` (http, PAT) on a known repo → returns hits.

### Phase 2 — Router (gating + orchestration)
7. Build `~/.claude/hooks/router.sh`:
   - read prompt (Phase 0.2);
   - `classify_domains()` — per-domain keyword/regex; github requires the entity regex (slug / `#\d+` / path / symbol);
   - for each matched domain, launch `mcp_retrieve.py` in background; `wait`; collect;
   - label each result (`<cognee-context>` etc.), truncate per-source + global;
   - print; **always exit 0**.
8. `chmod +x` both scripts.

### Phase 3 — Test in isolation (before wiring)
9. In-domain (each of the 3, and a multi-domain prompt) → correct labeled blocks present.
10. Out-of-domain ("capital of France") → empty output, exit 0.
11. github vague mention without an entity → **no** github fetch (gate holds).
12. One adapter down (bad URL) → others still return; total ≤ ~timeout; exit 0.

### Phase 4 — Wire the hook (RUNBOOK — user applies; Claude does not edit settings.json/hooks)
13. `UserPromptSubmit` → two commands: a thin residual reminder (only non-auto surfaces, e.g. HF) + `router.sh`. Example:
    ```json
    "UserPromptSubmit": [
      { "hooks": [
        { "type": "command", "command": "cat /home/cdfadmin/.claude/hooks/residual-reminder.md" },
        { "type": "command", "command": "/home/cdfadmin/.claude/hooks/router.sh" }
      ]}
    ]
    ```
14. Fresh session; confirm in-domain prompts arrive pre-augmented and the model uses context without a tool call.

### Phase 5 — Tune & observe
15. Adjust gates (precision/recall), top_k, caps, search types per real quality.
16. Log per-prompt {matched domains, latency, bytes injected} to audit gate accuracy.
17. Optional short-TTL cache keyed on normalized-prompt hash.

### Phase 6 — Promote toward real EF-013 Router
18. When EF-011/EF-012 land, fold this shim's gating + transport logic into the server-side Router (C4) so augmentation is shared across all clients, not just this Claude Code host.

---

## 8. Tradeoffs (accepted)
- **Latency:** bounded by parallel fan-out + per-adapter timeout; gate avoids network on out-of-domain prompts.
- **Blunt query:** adapters get the raw prompt, no mid-reasoning reformulation. Model can still call any MCP tool directly for targeted follow-up.
- **github asymmetry:** deliberately narrow (entity-triggered) — accept lower coverage to avoid noisy/expensive blind searches.
- **Recall-quality caveat:** cognee results inherit EF-011's open recall-quality work.

## 9. Open decisions for the user
- cognee search type: CHUNKS vs GRAPH_COMPLETION for injection?
- Gate engine: keyword/regex (fast) vs small classifier call (smarter, +latency)?
- github entity set: which entities count as triggers (slug / PR / issue / path / symbol — all? subset?)?
- Residual reminder: keep HF (and anything else) as model-discretion, or drop the reminder entirely?

## 10. SECURITY — remediate first
Live plaintext secrets surfaced during inspection — rotate (treat as compromised, they were displayed) and move into the sops-age vault (`[[reference_sops_age_secrets]]`):
- GitHub PAT in `~/.claude/settings.json` (`env.GITHUB_TOKEN`) and `~/.claude.json` (github MCP `Authorization` header).
- `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `LLM_API_KEY`, `EMBEDDING_API_KEY` in the `dkr-cgnee-mcp` container env.
The github adapter (§5) depends on a PAT — resolve it through the vault, not inline. Config/hook edits are handed to the user as a runbook (`[[feedback_config_changes_need_runbook]]`).

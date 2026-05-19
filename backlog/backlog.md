# Backlog

Active issues (`open`, `in-progress`, `blocked`) for this repo.

## Issue EF-010 — Self-consume cognee-mcp in this repo; runbook doubles as adopter onboarding
ID: EF-010
Title: Self-consume cognee-mcp in this repo; runbook doubles as adopter onboarding
Date: 2026-05-18
Status: open
Effort: S
Fix surface: repo-instance
Depends on: EF-001
Verify with: in this repo, `claude mcp list` shows cognee connected AND `recall` against the eposforge dataset returns expected entities from an MCP-capable dev product (claude-code at minimum). The same runbook, with a "for adopters: substitute your corpus and TTL overlay" section, satisfies what EF-005 originally tried to spec.
Notes: Supersedes EF-005. EposForge dogfoods its own pattern — the repo IS the first adopter, so the self-consumption setup is the primary deliverable and the adopter-facing framing is a derivative section. Runbook should cover: cognee-mcp install/config (stdio for local dev-products; SSE/HTTP variants noted), the `COGNEE_MCP_AGENT_SCOPED=false` + `ENABLE_BACKEND_ACCESS_CONTROL=false` decision for shared-backend single-graph mode vs per-dataset isolation, overlay TTL upload via cognee-sync (Phase 4 ontology behavior already documented in instance/installed/06-spec-graph/cognee/cognee.md), and minimal MCP-client config snippets for the supported dev-products (claude-code, cursor, copilot). Call out the .owl extension requirement (EF-004 still slated covers automating that on the sync CLI side). Blocked in practice until the cognee-mcp wrapper actually exposes tools to MCP clients — track that as a separate bug.

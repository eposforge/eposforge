# Backlog

Active issues (`open`, `in-progress`, `blocked`) for this repo.

## Issue EF-010 — Document adopter onboarding with upstream cognee-mcp + TTL overlay
ID: EF-010
Title: Document adopter onboarding with upstream cognee-mcp + TTL overlay
Date: 2026-05-18
Status: open
Effort: S
Fix surface: eposforge-pattern
Depends on: EF-001
Verify with: an adopter can follow the runbook end-to-end and (a) point cognee-mcp at their dkr-cgnee-api backend, (b) upload a TTL overlay that extends the canonical eposforge ontology via cognee-sync, (c) query the resulting KG via MCP `recall` from Claude Code / Cursor / etc.
Notes: Supersedes EF-005. Runbook should cover: cognee-mcp install/config (stdio + SSE/HTTP variants), the `COGNEE_MCP_AGENT_SCOPED=false` + `ENABLE_BACKEND_ACCESS_CONTROL=false` decision for shared-backend single-graph mode vs per-dataset isolation, overlay TTL upload via cognee-sync (Phase 4 ontology behavior already documented in instance/installed/06-spec-graph/cognee/cognee.md), and a minimal MCP-client config snippet for the supported dev-products (claude-code, cursor, copilot). Should also call out the .owl extension requirement (EF-004 still slated covers automating that on the sync CLI side).

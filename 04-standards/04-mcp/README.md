---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# MCP-First Routing Standard

## Status

- adopted: 2026-07-17
- supersedes: none
- declined-options: embedding integration logic in bash scripts or standalone CLI tools when an MCP abstraction applies.
- spec-version: n/a

## Scope

This standard governs how agents and tools access external capabilities, query knowledge graphs, and interact with adopter-provided context within the EposForge architecture. It enforces the Model Context Protocol (MCP) as the primary abstraction for capability routing.

## Normative requirements

1. **MCP is the Authoritative Source.** If a capability, index, or context is exposed via an MCP server (e.g., the Cognee Spec Graph), agents MUST use the MCP surface to query or interact with it rather than reinventing integration scripts, hitting databases directly, or assuming filesystem structures.
2. **When to Route to MCP.** When an agent needs to retrieve semantic information, domain knowledge, or contextual rules, it MUST route the query through the configured MCP server. Local filesystem searches (`rg`, `find`) should be reserved for deterministic structural checks, not semantic questions.
3. **Avoid Hardcoded Abstractions.** Agents MUST NOT build bespoke python scripts to query the graph if an MCP `recall` or equivalent tool is available. The MCP server is the single point of abstraction.
4. **Graceful Degradation.** If an MCP server is unreachable, agents MUST notify the operator and fall back to file-based tools (where applicable) rather than silently failing or providing ungrounded responses.

## Conformance

- Verify that agent instructions and skills prioritize MCP tool calls for semantic retrieval.
- Review scripts to ensure no redundant API/DB wrappers are built when an MCP server already covers the surface area.

## Related

- [../../AGENTS.md](../../AGENTS.md) — points to this standard for MCP-first behavior.
- [../00-standards-meta/standards-meta.md](../00-standards-meta/standards-meta.md)

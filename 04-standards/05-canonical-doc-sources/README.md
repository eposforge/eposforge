---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Canonical Source Policy

## Status

- adopted: 2026-07-17
- supersedes: none
- declined-options: duplicating architectural rules in IDE-specific `.md` files like `CLAUDE.md`.
- spec-version: n/a

## Scope

This standard establishes the source of truth for all documentation, specifications, and architectural rules in the EposForge framework. It prevents knowledge drift and contradictory instructions across different agent surfaces.

## Normative requirements

1. **Single Source of Truth.** The `AGENTS.md` file in the repository root is the canonical entry point for all agent behavior and guidance. Any IDE-specific configuration files (like `.github/copilot-instructions.md`, `CLAUDE.md`, or `GEMINI.md`) MUST be thin pointers that instruct the agent to read `AGENTS.md`.
2. **Ontology Ownership.** The `00-vision/01-ontology.ttl` file is the sole authoritative source for the domain ontology (dark factory pattern in OWL) and knowledge taxonomy. Prose documents and diagrams MUST align their terminology with the ontology, and agents MUST NOT redefine these terms in local files.
3. **Living Spec Contracts.** All component slots and adapters MUST document their contracts in `01-architecture/02-components/`. When checking what a component does or requires, agents MUST cite the component markdown file rather than relying on assumed knowledge or outdated project plans.
4. **File-based Backlog.** The `.eposforge/backlog/backlog.md` is the canonical source for work tracking. Scratchpads (`.scratchpad/`) are for temporary plans and execution state, not persistent definitions.

## Conformance

- Verify IDE instructions are pointers: `rg "AGENTS.md" CLAUDE.md` (or equivalent).
- Review agent outputs to ensure citations point to the canonical architecture files rather than scratchpads or memory.

## Related

- [../../AGENTS.md](../../AGENTS.md) — the entry point that enforces this policy.
- [../00-standards-meta/standards-meta.md](../00-standards-meta/standards-meta.md)

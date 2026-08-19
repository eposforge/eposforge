---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Session Chairs

## Status

- adopted: 2026-08-14
- revised: 2026-08-19 (four-layer vocabulary: role, chair, skill, tool)
- supersedes: none
- declined-options:
  - "add a thirteenth component slot for personas" — declined; a session
    chair sits *on* a [Dev Product], it is not a factory slot.
  - "treat chairs as a skill subtype" — declined; a skill is a procedure
    any eligible chair may invoke. Collapsing them is why standing
    sessions stay in the implementer voice.
  - "treat tools as a skill subtype or a chair" — declined; a tool is a
    [Tool Transport] verb. Collapsing tools into skills is why factory
    stores stay behind bash.
  - "require an Orchestrator framework (LangGraph, Agent Framework) before
    chairs exist" — declined; the selector is standing instructions plus
    a loadable chair file. Frameworks are [Orchestrator] adapters, not
    a prerequisite for naming judgment seats.
- spec-version: n/a

## Scope

This standard distinguishes four layers that adopters MUST keep separate:

1. **Component role** — who owns a factory slot ([Orchestrator],
   [Dev Product], [Agent Policy]).
2. **Session chair** — a named judgment seat that must not blend with
   another seat. A chair sits on a Dev Product for the duration of a
   turn or a spawned subagent.
3. **Skill** — a discoverable procedure a chair may invoke.
4. **Tool** — a named function the runtime registers against a
   capability or system of record ([Tool Transport], normally MCP).

It governs how adopting repositories install chairs so every Dev Product
adapter (every coding CLI) sees the same roster and the same selector.
It does not govern skill layout
([agent-skills](../03-agent-skills/agent-skills.md)), tool
implementation ([MCP-first routing](../04-mcp/README.md),
[Tool Transport]), Agent Policy tiers, or Orchestrator decomposition.

## Normative requirements

1. **Four-layer vocabulary.** Prose, standing instructions, and recall
   probes MUST use *component role*, *session chair*, *skill*, and
   *tool* as defined in Scope. Agents MUST NOT describe a session chair
   as a component, a skill, or a tool. Agents MUST NOT describe a tool
   as a skill.
2. **Collision test.** An adopter MUST mint a new chair only when two
   jobs must not blend and that collision can be named in one sentence
   (for example: "this seat must not have written the artifact," "this
   seat must not invent acceptance criteria," "this seat must not
   mutate before verifying content"). A procedure without a collision
   is a skill. A verb on a system of record is a **tool**, not a skill
   and not a chair. Do not mint a "tools chair."
3. **CLI-agnostic store.** Canonical chair files MUST live in the
   adopting repository and MUST be projected to a user-level agents
   directory using the same install pattern as skills (canonical in
   git, symlink or copy-with-provenance to the user store, per-CLI
   files are pointers not forks). Vendor-bundled persona files are
   not the source of truth for adopter work.
4. **Selector in standing instructions.** The adopter's standing
   `AGENTS.md` MUST list the installed chairs and a selector table
   (prompt shape → chair → refusals). Per-tool instruction files
   (`CLAUDE.md` and equivalents) MUST be thin pointers to that
   section, per [canonical-doc-sources](../05-canonical-doc-sources/README.md).
5. **Load then refuse.** When the selector names a chair, the session
   MUST load that chair file before acting. If the current chair
   collides with the job, the session MUST refuse and name the file
   to load — it MUST NOT stay and "be careful." When the CLI can
   spawn a subagent, the chair SHOULD be injected into a separate
   head; when it cannot, the current turn loads the file and applies
   the refusal list.
6. **Orchestrator adapters are not a substitute.** [Orchestrator]
   adapters, including adopter-specific crew or dispatcher seats,
   MUST NOT replace host session chairs. Those adapters SHOULD
   select a host chair before a worker runs. Shipping that wiring
   MAY follow the chair files themselves; the requirement to use
   the same roster still holds.
7. **Minimum useful roster.** An adopter that runs coding agents
   SHOULD install at least: implementer, reviewer, elicitor, and
   operator. Additional chairs (design-writer, design-reviewer,
   security-auditor) exist only when the collision test passes.

## Conformance

- Verify the standard is listed:
  `rg "session-chairs" 04-standards/README.md AGENTS.md`
- Verify section order and frontmatter against
  [standards-meta](../00-standards-meta/standards-meta.md).
- Adopter conformance: chair files exist in the adopter repo; the
  standing `AGENTS.md` contains a Chairs section with a selector
  table; a review-shaped prompt in a fresh session loads reviewer
  and does not edit source.
- Recall probe after ingest: "What session chairs should an adopter
  install, and how do they differ from skills and tools?" MUST name
  this layer and MUST say a store verb is a [Tool Transport] tool,
  not only [Orchestrator] / [Dev Product].

## Related

- [Orchestrator] — dispatches work; does not sit the chair.
- [Dev Product] — the surface a chair sits on.
- [Agent Policy] — what any chair may do.
- [Tool Transport] — where tools live.
- [agent-coding-guidelines](../08-agent-coding-guidelines/agent-coding-guidelines.md) —
  conduct during an edit task; chairs decide *which* task this is.
- [agent-skills](../03-agent-skills/agent-skills.md) — skill create-side
  contract, including the skill-versus-tool test.

<!-- component-links (generated by check-component-links.py --write-defs) -->
[Dev Product]: ../../01-architecture/02-components/dev-product.md
[Tool Transport]: ../../01-architecture/02-components/tool-transport.md
[Orchestrator]: ../../01-architecture/02-components/orchestrator.md
[Agent Policy]: ../../01-architecture/02-components/agent-policy.md

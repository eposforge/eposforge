---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Agent Skills

## Status

- adopted: 2026-08-19
- supersedes: none
- declined-options:
  - "treat a skill as the way to expose a system-of-record verb" —
    declined; that is a [Tool Transport] capability (normally an MCP
    tool). A skill may wrap tools with chair, order, dry-run, or a
    human gate. It MUST NOT be the only agent surface for a store
    verb.
  - "collapse skills into session chairs" — declined; see
    [session-chairs](../14-session-chairs/session-chairs.md).
  - "require every skill to declare Adapter metadata" — declined;
    metadata is optional except when a product skill touches a future
    Adapter.
- spec-version: n/a

## Scope

This standard is the create-side contract for agent skills in EposForge
and in adopting repositories. It governs when to mint a skill, how the
files are laid out, and how skills relate to tools, runbooks, and
prompt packs.

It does not govern install/projection onto CLI surfaces (that is the
consume-side contract: `skills/INSTALL.md` and EF-032 / EF-063). It
does not govern session chairs. It does not govern Tool Transport
protocol or server assignment.

## Normative requirements

1. **Layout.** A skill is a directory `skills/<name>/` whose required
   file is `SKILL.md`. Frontmatter MUST include `name` and
   `description`. The layout MUST be compatible with
   [agentskills.io](https://agentskills.io). Optional `scripts/` and
   `references/` live beside `SKILL.md`. The directory name and
   `name` field MUST be lowercase-hyphenated.

2. **Canonical store vs wrappers.** Canonical skill content MUST live
   under the owning repository's `skills/<name>/`.
   `.github/skills/<name>/SKILL.md` MUST be a thin wrapper that points
   at the canonical `SKILL.md` (and any needed references). Per-CLI
   copies are pointers or install projections, not forks.

3. **Content SoT is not auto-discovery.** Bare `skills/` is the
   content source of truth. A coding CLI MUST NOT be assumed to load
   that tree. Consume/install is a separate step
   (`skills/INSTALL.md`, EF-032, EF-063).

4. **Designation: skill vs tool vs runbook vs prompt pack.** Before
   creating a skill, apply this test. Exactly one designation wins.

   | Artifact | Essential characteristic | Mint when |
   |---|---|---|
   | **Tool** | A named function the runtime registers (schema, description, operator toggle). A verb on a system of record. | The body would be "call this API/CLI against a store" with structured inputs and outputs and no human gate in the middle. |
   | **Skill** | A discoverable procedure a [session chair](../14-session-chairs/session-chairs.md) may invoke. | Order, refusals, dry-run, or a human gate over one or more tools; or a repeatable recipe that is not a store verb. |
   | **Runbook** | Operator-facing procedure, usually invoked by a human or by an operator-chair session. | The audience is the operator restoring or operating infrastructure, not a Dev Product discovering a slash command. |
   | **Prompt pack** | One-off or local prompt text that is not versioned as a factory skill. | Personal or throwaway; MUST NOT be the SoT for a shared factory procedure. |

   A skill whose body is only a store verb (flags, URL, exit codes)
   is **non-conformant** unless those steps invoke an existing
   [Tool Transport] tool and the skill adds chair, order, dry-run, or
   a human gate. File a Tool Transport item instead of, or as well as,
   the skill.

   Platform/substrate lifecycle (host compose, elevation prompts,
   secret *set* that must not enter a transcript) MAY remain a skill
   or runbook. That exception is for human gates and host mutation,
   not for product or factory stores.

5. **Thin wrapper over tools.** When a skill ships helper scripts,
   the scripts are ordinary executables. They are not tools until a
   Tool Transport adapter registers them. The skill MUST tell the
   chair which tool or script to call; it MUST NOT imply that
   `scripts/` appears in a Dev Product tool picker.

6. **Adapter metadata (optional).** A product skill that touches a
   future Adapter SHOULD declare the Adapter fields from
   [the adapter pattern](../../01-architecture/00-adapter-pattern/adapter-pattern.md)
   that it already knows (`component`, `privacy_posture` when
   relevant). Every such skill MUST include a section titled
   `## Eposforge non-conformances` listing contract gaps (missing
   slot, unofficial invocation surface, policy not yet enforced).
   Skills that do not touch an Adapter omit both.

7. **Create checklist.** An agent that mints a skill MUST:

   1. Run the designation test in requirement 4 and record the
      winner. If the winner is **tool**, stop and file Tool
      Transport work.
   2. Write `skills/<name>/SKILL.md` with `name` and `description`
      (description MUST state trigger phrases).
   3. Add a thin `.github/skills/<name>/SKILL.md` wrapper when the
      repository uses GitHub skill discovery.
   4. Note consume/install projection (`skills/INSTALL.md` or the
      adopter overlay). Do not assume `skills/` auto-loads.
   5. Add `## Eposforge non-conformances` when requirement 6
      applies.

8. **Consume checklist.** An agent that installs or tells an operator
   how to use a skill MUST:

   1. Treat `skills/<name>/` as content SoT, not as "the CLI has
      this skill."
   2. Use `skills/INSTALL.md` / `skills/install.sh` (EF-032) and the
      fleet surfaces in EF-063 rather than hand-copying trees.
   3. Leave Tool Transport assignment (which MCP servers a CLI
      loads) to the MCP assignment plane (EF-080). Installing a
      skill does not register a tool.

## Conformance

- Verify the standard is listed:
  `rg "03-agent-skills" 04-standards/README.md AGENTS.md`
- Verify section order and frontmatter against
  [standards-meta](../00-standards-meta/standards-meta.md).
- Verify the designation table names tool, skill, runbook, and
  prompt pack:
  `rg -n "skill vs tool|Designation: skill vs tool" 04-standards/03-agent-skills/agent-skills.md`
- Verify a thin wrapper exists for at least one shipped framework
  skill:
  `rg -l "Thin wrapper" .github/skills/*/SKILL.md`
- Recall probe after ingest: "where do skills live" / "skill vs
  runbook" / "skill vs tool" MUST name this standard and MUST say a
  store verb is a [Tool Transport] tool.

## Related

- [session-chairs](../14-session-chairs/session-chairs.md) — chairs
  invoke skills; they are not skills.
- [mcp-first routing](../04-mcp/README.md) — consume existing MCP;
  expose factory SoR verbs as tools.
- [Tool Transport] — where tools live.
- [adapter-pattern](../../01-architecture/00-adapter-pattern/adapter-pattern.md) —
  `invocation_surface` may be MCP or a skill; the designation test
  chooses.
- Consume-side: `skills/INSTALL.md`, EF-032, EF-063.

<!-- component-links (generated by check-component-links.py --write-defs) -->
[Tool Transport]: ../../01-architecture/02-components/tool-transport.md

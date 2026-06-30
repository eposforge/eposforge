---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Agent Coding Guidelines

## Status

- adopted: 2026-06-12
- supersedes: none
- declined-options: per-tool installation (Claude Code plugin or per-project
  `CLAUDE.md` copies) — declined because tool-specific instruction files in
  this repo are thin pointers and `AGENTS.md` is the single source of truth
  for agent guidance; a second behavioral file would fork that model.
- spec-version: n/a

## Scope

This standard adopts four behavioral principles for AI coding agents working
in EposForge and in adopting repos that follow the `AGENTS.md`
single-source-of-truth pattern. It governs agent conduct during any edit
task. It does not govern document formats
([naming-conventions](../01-naming-conventions/naming-conventions.md)) or
backlog mechanics.

Upstream: derived from Andrej Karpathy's published observations on LLM
coding pitfalls and the MIT-licensed distillation at
[multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)
(formerly `forrestchang/andrej-karpathy-skills`).

## Normative requirements

1. **Think before coding.** Agents MUST state assumptions explicitly,
   present competing interpretations rather than picking one silently, push
   back when a simpler approach exists, and stop to ask when confused
   rather than hiding the confusion.
2. **Simplicity first.** Agents MUST produce the minimum change that solves
   the problem: no unrequested features, no abstractions for single-use
   content, no speculative flexibility or configurability, no handling for
   impossible scenarios.
3. **Surgical changes.** Agents MUST NOT modify content unrelated to the
   task (adjacent prose, formatting, comments, pre-existing dead content) —
   unrelated problems are reported, not fixed in-band. Agents MUST remove
   orphans their own change created, and only those. Every changed line
   must trace directly to the request.
4. **Goal-driven execution.** Agents MUST restate a task as verifiable
   success criteria before executing — for this repo's Markdown artifacts
   that means a named conformance command, lint script, or recall query —
   and loop until the criteria are verified. For multi-step work, state a
   brief plan with a verify step per item.
5. **Public/private boundary hygiene (no leaking adopter identifiers).** Agents MUST NEVER name, reference by identifier, or include paths for any specific adopter repository (including the primary Adopter Platform Spec or examples such as any private org repo) inside this public repository's docs, plans, standards, comments, examples, backlog items, or code. Always use only abstract/generic language: "the primary adopter", "an adopting repository", "the Adopter Platform Spec", etc. Specific names and operational details belong exclusively in the adopter's private trees. Before editing any document that discusses adoption or layout, recall the current public/private rules via the appropriate tool. Violations must be treated as sensitive-literal errors.
6. `AGENTS.md` MUST carry a condensed statement of principles 1–5 so they
   are in loaded context every session; this file remains the source of
   truth.

The bias is toward caution over speed. For trivial edits (typo fixes,
obvious one-liners), proportional judgment applies.

## Conformance

- Verify `AGENTS.md` carries the condensed section:
  `rg "Agent coding guidelines" AGENTS.md`
- Review signal in pull requests: diffs contain only requested changes;
  clarifying questions appear before implementation, not after mistakes;
  no drive-by refactoring or "improvements".

## Related

- [../../AGENTS.md](../../AGENTS.md) — condensed in-context statement
- [../00-standards-meta/standards-meta.md](../00-standards-meta/standards-meta.md)
- Upstream: <https://github.com/multica-ai/andrej-karpathy-skills> (MIT)
  and <https://x.com/karpathy/status/2015883857489522876>

---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Adapter Layout Mirror

## Status

- adopted: 2026-05-24
- supersedes: none
- spec-version: tracks the canonical knowledge tree (not a fixed path set)

## Scope

Governs where an adopting repo places (a) the eposforge component/adapter
implementations it installs and (b) its backlog data — so an adopter's layout
mirrors eposforge's and cross-repo tooling (`aggregate.sh`, the Spec Graph) can
traverse repos uniformly. Anchored on node identity in the canonical knowledge
tree, NOT on any hardcoded numbered path.

This standard does not govern an adopter's own application source layout.

## Normative requirements

1. Installed component/adapter implementations MUST mirror the canonical
   knowledge-tree component nodes by **node identity**, not by a hardcoded
   numbered path. A path is a projection of its tree node ("directory mirrors
   the knowledge tree"); the node name is the stable anchor across re-shelving.
2. eposforge (the pattern repo) installs its self-implementation under
   `instance/installed/<component>/<adapter>/` to separate the normative pattern
   from its dogfooded implementation. A pure ADOPTER has only implementation and
   MUST NOT reproduce the `instance/installed/` layer — components sit directly
   at the adoption root: `<adoption-root>/<component>/<adapter>/`.
   - **Adopter container name:** `eposforge/` — all eposforge-owned content for
     an adopting repo lives under this single top-level directory. The framework
     repo uses `instance/` for the same role (to avoid a confusing self-duplicate).
3. Backlog DATA (the issue files) MUST live at `<adoption-root>/backlog/`
   (mirroring eposforge's `instance/backlog/`), distinct from the
   file-based-backlog ADAPTER (scripts + living spec) at its component path.
   Data is repo content; the adapter is the tool that operates on it.
   - **Prescriptive core per installed adapter:** data files + `config.toml`.
     The Living Spec (`file-based-backlog.md`) is part of the model but may be
     deferred on first adoption. Framework conveniences (`instance/README.md`
     slot-table, `instance/adrs/`, `instance/`.audit/`) are NOT prescribed —
     adopters omit them.
4. Each repo carries exactly one backlog instance with a repo-scoped ID prefix.
   Cross-repo dependency references MUST name the **bare ID only**; a public repo
   MUST NOT embed another repo's name or path in a reference. Dependency
   direction MUST be kept so a public repo never references a private repo's IDs.
5. A change to the tree's component structure MUST ship with a tree version bump
   and a machine-readable old->new rename map; adopters re-shelve via the
   migration skill on their own schedule (pinning a tree version). This standard
   enumerates no paths — it points at the tree.
6. **Discovery wiring (required):** each repo MUST declare its adoption-root via
   a `.code-workspace` file. The adapter scripts' git-root fallback checks
   `<repo-root>/backlog/config.toml`, which misses when the backlog is nested
   under a container (`eposforge/backlog/` for adopters, `instance/backlog/` for
   the framework). Without a workspace file, Preferred-mode invocations silently
   find zero items.
   - Adopters: workspace `folders` must include `./eposforge` and
     `../../gh/eposforge` (the framework clone, for cross-repo aggregation).
   - Framework repo: workspace `folders` must include `.` and `./instance`.
   - `BACKLOG_ROOTS` remains the pure-CLI fallback when no workspace file is active.

## Conformance

- Adopter-layout check: each installed component/adapter path resolves to a live
  tree node by identity; orphans (no matching node) fail.
- Backlog-location check: data at `<adoption-root>/backlog/` (i.e.
  `eposforge/backlog/` for adopters, `instance/backlog/` for the framework);
  adapter at its component path. A workspace file declaring the adoption-root
  must be present.
- `aggregate.sh` discovers per-repo backlogs via workspace / `BACKLOG_ROOTS` and
  rolls them into one cross-repo view.

## Related

- [../00-standards-meta/standards-meta.md](../00-standards-meta/standards-meta.md)
- [../06-research-mirror/research-mirror.md](../06-research-mirror/research-mirror.md) (sibling mirror standard)
- [../../01-architecture/00-adapter-pattern.md](../../01-architecture/00-adapter-pattern.md)

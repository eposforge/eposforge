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

This standard does not govern an adopter's own application source layout. However, EposForge recommends (and adopters should follow) a clear pattern for the primary repo:

An adopter designates **one primary repo** as the "Adopter Platform Spec" for the environment. This single repo:
- Contains the documentation describing the adopter's overall eposforge implementation (both the Platform Factory and Product Factory sides).
- Includes the `eposforge/` bucket (the adopted pattern slice with stable component/adapter layout).
- Acts as the anchor for cross-repo views such as portfolio reviews.

GEA is the canonical example of this primary repo. Product repos and other implementation repos remain separate but can be discovered from the primary via workspace files or BACKLOG_ROOTS for a unified portfolio view.

See the architecture capture and implementation plan (tracked by EF-056) for the multi-graph and boundaries model. The adapter-layout-mirror rules below ensure the `eposforge/` slice is uniform so tooling works.

## Normative requirements

1. Installed component/adapter implementations MUST mirror the canonical
   knowledge-tree component nodes by **node identity**, not by a hardcoded
   numbered path. A path is a projection of its tree node ("directory mirrors
   the knowledge tree"); the node name is the stable anchor across re-shelving.
2. The framework installs its self-implementation (adapters) under
   `instance/<component>/<adapter>/` . A pure ADOPTER has only implementation
   and uses `<adoption-root>/<component>/<adapter>/` directly (container is
   `eposforge/`). Component directories use the stable node name (no numeric
   prefixes). The authoritative component node names are: spec-input,
   living-spec, dev-product, router, tool-transport, spec-graph,
   execution-sandbox, agent-policy, source-control-ci, release-rings,
   inference, audit-observability, secrets-key-management, backlog.
   For the backlog component the adapter implementation lives at
   `<container>/backlog/file-based-backlog/` (co-located under the data root
   for that component; data files live as siblings at the `backlog/` level).
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
   (The framework's `instance/` is its adoption-root / container equivalent.)
   - `BACKLOG_ROOTS` remains the pure-CLI fallback when no workspace file is active.

## Conformance

- Adopter-layout check: each installed component/adapter path resolves to a live
  tree node by identity (using the stable node names listed above); orphans fail.
- Backlog-location check: data at `<adoption-root>/backlog/` (i.e.
  `eposforge/backlog/` for adopters, `instance/backlog/` for the framework);
  the file-based-backlog adapter at `.../backlog/file-based-backlog/`. A
  workspace file declaring the adoption-root must be present.
- `aggregate.sh` discovers per-repo backlogs via workspace / `BACKLOG_ROOTS` and
  rolls them into one cross-repo view.

## Related

- [../00-standards-meta/standards-meta.md](../00-standards-meta/standards-meta.md)
- [../06-research-mirror/research-mirror.md](../06-research-mirror/research-mirror.md) (sibling mirror standard)
- [../../01-architecture/00-adapter-pattern/adapter-pattern.md](../../01-architecture/00-adapter-pattern/adapter-pattern.md)

See `docs/eposforge-gea-architecture-discussion-capture.md` and `docs/implementation-plan-eposforge-gea-architecture.md` (tracked by EF-056). This standard covers the technical rules for the `eposforge/` slice inside an adopter's primary repo. The primary repo itself (e.g. GEA) is the place where overall eposforge implementation documentation lives and where portfolio reviews are performed. AGENTS.md is the SSoT for agent instructions on using dedicated backlog-graph tools + explicit markup over raw file RAG. See also EF-047/048 for public/private concerns.

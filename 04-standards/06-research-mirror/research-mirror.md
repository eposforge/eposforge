---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Research Mirror

## Status

- adopted: 2026-05-16
- supersedes: none
- declined-options: [../../../03-research/04-standards/06-research-mirror/](../../../03-research/04-standards/06-research-mirror/)
- spec-version: n/a

## Scope

This standard governs the path invariant between source markdown files and their research mirror paths under `03-research/`.

This standard does not govern cross-cutting root files `03-research/README.md` and `03-research/landscape.md`.

## Normative requirements

1. For any source file `<repo-root>/<path>/<file>.md`, related research MUST live under `03-research/<path>/<file>/`.
2. Every file under `03-research/<path>/` (excluding approved cross-cutting root files) MUST correspond to a real source file at `<repo-root>/<path>.md`.
3. Source path refactors (move, rename, delete) MUST move or remove the mirrored `03-research/<path>/` folder in the same change.
4. The mirror MUST be need-based: folders MAY be absent when no research exists and MUST NOT be created speculatively.
5. Filenames inside mirrored folders MAY be content-descriptive and do not need to match the source filename.
6. Transitional empty mirror folders MAY exist briefly during a refactor but SHOULD be removed if they remain empty.

## Conformance

- Run a tree-diff validation script that checks each non-cross-cutting markdown file in `03-research/` resolves to an existing source markdown path.
- Search for orphan mirror roots with: `rg --files 03-research` and compare against source markdown files.
- Pull requests that refactor source paths MUST include corresponding mirror path updates.

## Related

- [../00-standards-meta/standards-meta.md](../00-standards-meta/standards-meta.md)
- [../../03-research/README.md](../../03-research/README.md)
- [../../../03-research/04-standards/06-research-mirror/structural-alternatives.md](../../../03-research/04-standards/06-research-mirror/structural-alternatives.md)

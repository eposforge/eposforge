---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Standards Meta

## Status

- adopted: 2026-05-16
- supersedes: none
- declined-options: none
- spec-version: n/a

## Scope

This standard governs how EposForge adopts, records, and supersedes standards under `04-standards/`.

This standard does not govern component-level contracts in `01-architecture/02-components/`.

## Normative requirements

1. Standards MUST live under `04-standards/<nn>-<slug>/` with one primary `*.md` source-of-truth file per standard folder.
2. Standard files MUST include frontmatter with `doc_kind: standard`, `scope`, `maturity`, and `source_of_truth: yes`.
3. Standard files MUST include sections in this order: `Status`, `Scope`, `Normative requirements`, `Conformance`, `Related`.
4. `Status` MUST include `adopted`, `supersedes`, and `declined-options`.
5. Adopted standards MUST be listed in `04-standards/README.md`.
6. A superseded standard MUST keep its file, set `maturity: superseded`, and name the replacement in `supersedes` or `Related`.

## Conformance

- Verify file layout with: `rg --files 04-standards`
- Verify required frontmatter fields with: `rg "doc_kind: standard|source_of_truth: yes" 04-standards`
- Verify section order by markdown review in pull request.

## Related

- [../README.md](../README.md)
- [../06-research-mirror/research-mirror.md](../06-research-mirror/research-mirror.md)
- [../../03-research/04-standards/](../../03-research/04-standards/)

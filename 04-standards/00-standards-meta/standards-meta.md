---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Standards Meta

## Status

- adopted: 2026-05-16
- revised: 2026-06-28 (relaxed "MUST keep superseded file" to allow removal for readability; git + explicit supersedes metadata is sufficient)
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
6. A superseded standard MUST record the supersession clearly in its `Status` section (using `supersedes`, `superseded-by`, or `superseded` date + link to replacement). The physical file MAY be removed once superseded (git history preserves the prior version); removal is permitted when retaining the directory harms readability of the active standards tree.

## Conformance

- Verify file layout with: `rg --files 04-standards`
- Verify required frontmatter fields with: `rg "doc_kind: standard|source_of_truth: yes" 04-standards`
- Verify section order by markdown review in pull request.
- For superseded standards: confirm the replacement records the link in `Status`, and the old directory is absent from the active tree (git history is the record).

## Related

- [../README.md](../README.md)
- [../06-research-mirror/research-mirror.md](../06-research-mirror/research-mirror.md)
- [../../03-research/04-standards/](../../03-research/04-standards/)

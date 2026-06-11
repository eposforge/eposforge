---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Naming Convention Alternatives

## Summary

This note records alternatives considered before adopting `04-standards/01-naming-conventions/naming-conventions.md`.

## Declined options

1. Mixed case for headings and file names.
Reason declined: lowers predictability for tooling and grep-based conformance checks.

2. Environment-specific endpoint examples in docs.
Reason declined: risks leakage of internal topology details and violates portability goals.

3. Separate naming rules by directory.
Reason declined: increases policy drift and review complexity.

## Adopted direction

A single cross-cutting naming and hygiene standard under `04-standards/01-naming-conventions/`.

---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Research Mirror Structural Alternatives

## Summary

This note records alternatives considered before adopting `04-standards/06-research-mirror/research-mirror.md`.

## Declined options

1. Flat per-component research folders at `03-research/<component>/...`.
Reason declined: does not mirror source paths and drifts during architecture refactors.

2. Sibling `standards/` outside `03-research/` for declined options.
Reason declined: breaks discoverability and weakens source-to-research path determinism.

3. Speculative empty mirror trees for every source file.
Reason declined: creates noise and does not reflect actual research inventory.

## Adopted direction

Need-based path mirroring where research for `<path>.md` lives in `03-research/<path>/`.

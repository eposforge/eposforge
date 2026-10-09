# Changelog

## 2026-10-09

- Initial skill. Generalized from an earlier single-domain draft: the Area
  vocabulary now comes from each repo's ideas-file header, and IDs are
  `<PREFIX>-IDEA-NNN` using the repo's backlog prefix.
- Register location fixed at `.eposforge/ideas/ideas.md`, beside the backlog.
- Workflows: capture (split, duplicate check including rejected entries,
  next ID, sparse fill, append), promote (ordinary backlog item, then
  `promoted → ID` and a `promoted-to` edge), reject (with a reason), edit.
- Typed **Edges** field with a closed vocabulary replaces a free-text Related
  field: symmetric edges written on both nodes, directed edges on the source
  only, no written inverses, dangling-edge check on add and edit.
- "Analyzing the register" section: clusters, prerequisite chains, conflicts,
  and what a backlog item would serve.
- Evals and trigger cases.

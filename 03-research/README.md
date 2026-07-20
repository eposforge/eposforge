---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# Research

Research materials organized as a need-based mirror of source document paths.

## Organization

Research paths mirror source paths.

- Research for `<path>.md` lives at `03-research/<path>/`.
- The mirror is need-based: folders exist only when research exists.
- Cross-cutting root files (`README.md`, `landscape.md`) stay at `03-research/` root.
- Normative rule: [../04-standards/06-research-mirror/research-mirror.md](../04-standards/06-research-mirror/research-mirror.md).

Currently populated mirrored paths:

- [01-architecture/02-components/spec-input/](01-architecture/02-components/spec-input/)
- [01-architecture/02-components/living-spec/](01-architecture/02-components/living-spec/)
- [01-architecture/02-components/dev-product/](01-architecture/02-components/dev-product/)
- [01-architecture/02-components/orchestrator/](01-architecture/02-components/orchestrator/)
- [01-architecture/02-components/tool-transport/](01-architecture/02-components/tool-transport/)
- [01-architecture/02-components/spec-graph/](01-architecture/02-components/spec-graph/)
- [01-architecture/02-components/execution-sandbox/](01-architecture/02-components/execution-sandbox/)
- [01-architecture/02-components/source-control-ci/](01-architecture/02-components/source-control-ci/)
- [01-architecture/02-components/inference/](01-architecture/02-components/inference/)
- [01-architecture/02-components/audit-observability/](01-architecture/02-components/audit-observability/)
- [01-architecture/02-components/secrets-key-management/](01-architecture/02-components/secrets-key-management/)
- [04-standards/01-naming-conventions/](04-standards/01-naming-conventions/)
- [04-standards/06-research-mirror/](04-standards/06-research-mirror/)

## Cross-Cutting Research

### landscape.md

Competitive and adjacent technology landscape scan. Updated periodically to track market positioning and differentiation of EposForge.

---

## Adding Research

When adding new research materials:

1. **Identify the source markdown file** the research supports
2. **Place research in the mirrored folder** at `03-research/<path-to-source-without-.md>/`
3. **Name files descriptively** (e.g., `design-patterns.md`, `competitive-analysis.md`)
4. **Link from the source doc** where relevant


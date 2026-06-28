---
doc_kind: operator-runbook
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# instance/ — EposForge Self-Host Layer

This directory is the self-host layer for this repository's dark factory.
It contains the concrete adapter choices, scripts, and repo-instance ADRs
that make THIS repo work. The `graphrag/` subtree is an archived snapshot
retained only in case GraphRAG is ever revived; it is not part of the active
EposForge implementation or guidance.

## Slot fillers (this repo)

| Slot | Status | Adapter | Living Spec | Slot contract |
|---|---|---|---|---|
| Spec Input | unfilled | hand-authored Markdown briefs | _none_ | [../01-architecture/02-components/spec-input.md](../01-architecture/02-components/spec-input.md) |
| Living Spec | filled | Markdown + classification frontmatter | [SPEC.md](./SPEC.md) | [../01-architecture/02-components/living-spec.md](../01-architecture/02-components/living-spec.md) |
| Dev Product | filled | Claude Code / Copilot / Gemini CLI | [dev-product/](./dev-product/) | [../01-architecture/02-components/dev-product.md](../01-architecture/02-components/dev-product.md) |
| Router | unfilled | operator-as-router | _none_ | [../01-architecture/02-components/router.md](../01-architecture/02-components/router.md) |
| Tool Transport | filled | MCP server set | [tool-transport/mcp-stdio-and-http/mcp-stdio-and-http.md](./tool-transport/mcp-stdio-and-http/mcp-stdio-and-http.md) | [../01-architecture/02-components/tool-transport.md](../01-architecture/02-components/tool-transport.md) |
| Spec Graph | filled | Cognee (embedded Kuzu + LanceDB; GraphRAG/Neo4j archived snapshot retained only for possible revival) | [SPEC.md](./SPEC.md) · [spec-graph/](./spec-graph/) | [../01-architecture/02-components/spec-graph.md](../01-architecture/02-components/spec-graph.md) |
| Execution Sandbox | partial | Windows ACL user | [execution-sandbox/windows-acl-user/windows-acl-user.md](./execution-sandbox/windows-acl-user/windows-acl-user.md) | [../01-architecture/02-components/execution-sandbox.md](../01-architecture/02-components/execution-sandbox.md) |
| Agent Policy | filled | tier-yaml | [agent-policy/tier-yaml/tier-yaml.md](./agent-policy/tier-yaml/tier-yaml.md) | [../01-architecture/02-components/agent-policy.md](../01-architecture/02-components/agent-policy.md) |
| Source Control / CI | filled | GitHub + GitHub Actions | [source-control-ci/github-and-actions/github-and-actions.md](./source-control-ci/github-and-actions/github-and-actions.md) | [../01-architecture/02-components/source-control-ci.md](../01-architecture/02-components/source-control-ci.md) |
| Release Rings | unfilled | none | _none_ | [../01-architecture/02-components/release-rings.md](../01-architecture/02-components/release-rings.md) |
| Inference | filled | Anthropic Claude (completion) | [inference/anthropic/anthropic.md](./inference/anthropic/anthropic.md) | [../01-architecture/02-components/inference.md](../01-architecture/02-components/inference.md) |
| Inference | filled | OpenAI Embeddings | [inference/openai/openai.md](./inference/openai/openai.md) | [../01-architecture/02-components/inference.md](../01-architecture/02-components/inference.md) |
| Audit & Observability | filled | JSONL event sink | [audit-observability/jsonl-event-sink/jsonl-event-sink.md](./audit-observability/jsonl-event-sink/jsonl-event-sink.md) | [../01-architecture/02-components/audit-observability.md](../01-architecture/02-components/audit-observability.md) |
| Secrets | filled | env vars + OS credential manager | [secrets-key-management/env-vars-and-os-credstore/env-vars-and-os-credstore.md](./secrets-key-management/env-vars-and-os-credstore/env-vars-and-os-credstore.md) | [../01-architecture/02-components/secrets-key-management.md](../01-architecture/02-components/secrets-key-management.md) |

## Adopting the pattern

If you are building your own dark factory, start with the spec layer:
`00-vision/`, `01-architecture/`, `02-roadmap/`, and `03-research/`.
Pick your own adapters for each slot. You can mirror this `instance/`
layout if it is useful, but these concrete choices are not prescriptive.

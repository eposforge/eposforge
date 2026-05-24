---
doc_kind: operator-runbook
scope: repo-instance
maturity: experimental
source_of_truth: yes
---

# instance/ — EposForge Self-Host Layer

This directory is the self-host layer for this repository's dark factory.
It contains the concrete adapter choices, scripts, GraphRAG pipeline, and
repo-instance ADRs that make THIS repo work. It is illustrative reference
implementation material, not normative guidance for other adopters.

## Slot fillers (this repo)

| Slot | Status | Adapter | Living Spec | Slot contract |
|---|---|---|---|---|
| 01 Spec Input | unfilled | hand-authored Markdown briefs | _none_ | [../01-architecture/02-components/01-spec-input.md](../01-architecture/02-components/01-spec-input.md) |
| 02 Living Spec | filled | Markdown + classification frontmatter | [SPEC.md](./SPEC.md) | [../01-architecture/02-components/02-living-spec.md](../01-architecture/02-components/02-living-spec.md) |
| 03 Dev Product | filled | Claude Code / Copilot / Gemini CLI | [installed/03-dev-product/](./installed/03-dev-product/) | [../01-architecture/02-components/03-dev-product.md](../01-architecture/02-components/03-dev-product.md) |
| 04 Router | unfilled | operator-as-router | _none_ | [../01-architecture/02-components/04-router.md](../01-architecture/02-components/04-router.md) |
| 05 Tool Transport | filled | MCP server set | [installed/05-tool-transport/mcp-stdio-and-http/mcp-stdio-and-http.md](./installed/05-tool-transport/mcp-stdio-and-http/mcp-stdio-and-http.md) | [../01-architecture/02-components/05-tool-transport.md](../01-architecture/02-components/05-tool-transport.md) |
| 06 Spec Graph | filled | Cognee (embedded Kuzu + LanceDB; GraphRAG/Neo4j installed as shelved fallback) | [SPEC.md](./SPEC.md) · [installed/06-spec-graph/](./installed/06-spec-graph/) | [../01-architecture/02-components/06-spec-graph.md](../01-architecture/02-components/06-spec-graph.md) |
| 07 Execution Sandbox | partial | Windows ACL user | [installed/07-execution-sandbox/windows-acl-user/windows-acl-user.md](./installed/07-execution-sandbox/windows-acl-user/windows-acl-user.md) | [../01-architecture/02-components/07-execution-sandbox.md](../01-architecture/02-components/07-execution-sandbox.md) |
| 08 Agent Policy | unfilled | ad-hoc AGENTS.md policy prose | _none_ | [../01-architecture/02-components/08-agent-policy.md](../01-architecture/02-components/08-agent-policy.md) |
| 09 Source Control / CI | filled | GitHub + GitHub Actions | [installed/09-source-control-ci/github-and-actions/github-and-actions.md](./installed/09-source-control-ci/github-and-actions/github-and-actions.md) | [../01-architecture/02-components/09-source-control-ci.md](../01-architecture/02-components/09-source-control-ci.md) |
| 9b Release Rings | unfilled | none | _none_ | [../01-architecture/02-components/09b-release-rings.md](../01-architecture/02-components/09b-release-rings.md) |
| 10 Inference | filled | Anthropic Claude (completion) | [installed/10-inference/anthropic/anthropic.md](./installed/10-inference/anthropic/anthropic.md) | [../01-architecture/02-components/10-inference.md](../01-architecture/02-components/10-inference.md) |
| 10 Inference | filled | OpenAI Embeddings | [installed/10-inference/openai/openai.md](./installed/10-inference/openai/openai.md) | [../01-architecture/02-components/10-inference.md](../01-architecture/02-components/10-inference.md) |
| 11 Audit & Observability | unfilled | git log + GraphRAG community reports | _none_ | [../01-architecture/02-components/11-audit-observability.md](../01-architecture/02-components/11-audit-observability.md) |
| 12 Secrets | filled | env vars + OS credential manager | [installed/12-secrets-key-management/env-vars-and-os-credstore/env-vars-and-os-credstore.md](./installed/12-secrets-key-management/env-vars-and-os-credstore/env-vars-and-os-credstore.md) | [../01-architecture/02-components/12-secrets-key-management.md](../01-architecture/02-components/12-secrets-key-management.md) |

## Adopting the pattern

If you are building your own dark factory, start with the spec layer:
`00-vision/`, `01-architecture/`, `02-roadmap/`, and `03-research/`.
Pick your own adapters for each slot. You can mirror this `instance/`
layout if it is useful, but these concrete choices are not prescriptive.

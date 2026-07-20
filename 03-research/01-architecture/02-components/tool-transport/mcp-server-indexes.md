---
doc_kind: candidate-research
scope: eposforge-pattern
maturity: draft
source_of_truth: no
---

# MCP Server Indexes — Declined as Tool Transport / Discovery Substrate

## Summary

This note records evaluation of **community MCP server directories and
hosted search indexes** (for example TensorBlock
[awesome-mcp-servers](https://github.com/TensorBlock/awesome-mcp-servers)
and its MCP Index API) against the Tool Transport slot and against
discover-before-build infrastructure.

These products are **catalogs of MCP servers with search on top** —
sometimes exposed via HTTP and sometimes via a small "search this
catalog" MCP. They do not implement factory capabilities.

## What was considered

- Community-curated lists of MCP servers (markdown categories, large
  entry counts).
- Hosted APIs that search normalized profiles and generate
  install-config previews for consumer clients (Claude Desktop,
  Cursor, Codex, VS Code).
- Local or remote "registry MCP" tools (`search_servers`,
  `get_server_profile`, `get_install_config`).

## Declined options

1. **Tool Transport Adapter candidate.**  
   Reason declined: an index **lists** servers; it does not **expose**
   the required capability categories (git, fs, shell, graph-query,
   browser, http) to Dev Products. Capability providers remain
   individual MCP servers (or other transports) selected and wired by
   the instance.

2. **First-class discovery substrate for discover-before-build.**  
   Reason declined: outbound discovery for on-demand software is Spec
   Graph first, then **commodity** search (code hosts, package
   registries, web / AI search). Vertical niche indexes overlap that
   plane, go stale, and typically carry low install/auth/transport
   metadata confidence. They are not a substitute for intent/contract
   match at the Living Spec layer.

3. **Auto-apply install-config into factory MCP wiring.**  
   Reason declined: generated snippets target consumer client JSON
   shapes. Factory instances re-express approved servers through their
   own declaration and secrets path (for example a canonical server
   list plus secret injection). Index install-config is a human recon
   hint only.

## Adopted direction

- Treat MCP server indexes as **optional, disposable recon** when an
  operator is hunting for a capability-providing MCP. Do not add them
  as catalog candidates in
  [tool-transport.md](./tool-transport.md).
- Prefer evaluating **specific** MCP servers (or other transports)
  against the Tool Transport contract and instance policy.
- Invest short-term effort in **publishable** Living Specs and
  Adapters so peer factories and commodity search can find factory
  outputs — see the OSS flywheel in
  [00-vision/00-vision.md](../../../../00-vision/00-vision.md).

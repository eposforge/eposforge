---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Naming Conventions

## Status

- adopted: 2026-05-16
- supersedes: AGENTS.md#conventions
- declined-options: [../../../03-research/04-standards/01-naming-conventions/](../../../03-research/04-standards/01-naming-conventions/)
- spec-version: n/a

## Scope

This standard governs naming and documentation hygiene conventions for EposForge docs and examples.

This standard does not govern external product naming conventions used by adapter vendors.

## Normative requirements

1. Docs MUST use American English.
2. File and heading names MUST be lowercase-hyphenated.
3. Docs MUST NOT include internal environment identifiers such as private IP addresses, internal hostnames, internal DNS zones, machine names, VPN details, or user-specific network topology.
4. Docs, plans, standards, code comments, examples, and backlog items in this public repository MUST NOT name any specific adopter repository (primary or otherwise), its identifier, or its full path. Use only generic terms such as "the primary adopter", "an adopting repository", "the Adopter Platform Spec repo", or "adopting repos". Specific adopter names are private and must remain only in the adopter's own private backlog and docs.
5. Example endpoints MUST use placeholders such as `https://<service-host>` and `bolt://<neo4j-host-or-ip>:7688`.
6. Committed docs MUST NOT include secrets, API keys, or passwords.
7. Components MUST be referenced by their **canonical descriptive name**
   from the [Component Catalog](../../01-architecture/02-components/README.md),
   never by a number. Numeric component identifiers (`C4`, `C14`,
   `Component 14`, etc.) MUST NOT be used to refer to a component — they
   are opaque to readers, have no decoder, and have drifted out of sync
   with the contracts.
8. A component reference in prose SHOULD be a Markdown **shortcut
   reference link** on the canonical name (`[Orchestrator]`), resolved by
   a per-file link-definitions block. Use the full reference form
   (`[dispatcher][Orchestrator]`) when different surface text is wanted;
   the bracketed label MUST match a catalog name. The definitions block
   is generated and validated by `check-component-links.py` (see
   [Component references](#component-references)).
9. Capitalize a component's name in prose when it denotes the component
   (`the Orchestrator dispatched`); lowercase the same word when it
   denotes the general concept (`a model router`). Capitalization is a
   readability aid for humans, not the machine signal — the bracket is.

## Component references

Components carry stable descriptive names, not numbers. The canonical
roster — name, contract file, one-line role — is the
[Component Catalog](../../01-architecture/02-components/README.md), which
is also the machine-readable source the lint parses.

To reference a component, wrap its canonical name in a shortcut
reference link and let a per-file definitions block resolve the path:

```markdown
The [Orchestrator] dispatches to a [Dev Product] in an [Execution Sandbox].

<!-- component-links (generated) -->
[Orchestrator]: ./orchestrator.md
[Dev Product]: ./dev-product.md
[Execution Sandbox]: ./execution-sandbox.md
```

Why this shape:

- **Readable in CLI/agent windows** — inline cost is two brackets; paths
  live once at the foot of the file, not scattered through prose.
- **Unambiguous to agents** — the bracket is a hard token the model
  reads directly, unlike capitalization, which is a weak, probabilistic
  signal that vanishes in headings and sentence-initial position.
- **Self-decoding** — the link resolves to the contract, so no separate
  lookup table is needed.
- **Lint-checkable** — a bracketed name with no definition, a definition
  to a missing file, or a residual component-number is a hard failure.

Generate/refresh a file's definitions block with
`check-component-links.py --write-defs <file>`; CI enforces it with
`check-component-links.py --check`.

## Conformance

- Review changed docs in pull requests for naming format and placeholder hygiene.
- Search for disallowed endpoint literals with: `rg "bolt://(?!<neo4j-host-or-ip>)|https?://(?!<)"`.
- Verify no secrets are committed with existing repository checks.
- Run the sensitive-literals check (or equivalent) and manually confirm no specific adopter repository names appear in public content. Use `rg "GraceEnterprisesArchitecture|GEA"` (post-scrub this should return nothing in the public tree except possibly in git history).

## Related

- [../../AGENTS.md](../../AGENTS.md)
- [../../00-vision/01-ontology.ttl](../../00-vision/01-ontology.ttl)
- [../../../03-research/04-standards/01-naming-conventions/case-and-prefix-options.md](../../../03-research/04-standards/01-naming-conventions/case-and-prefix-options.md)

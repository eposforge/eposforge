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
4. Example endpoints MUST use placeholders such as `https://<service-host>` and `bolt://<neo4j-host-or-ip>:7688`.
5. Committed docs MUST NOT include secrets, API keys, or passwords.

## Conformance

- Review changed docs in pull requests for naming format and placeholder hygiene.
- Search for disallowed endpoint literals with: `rg "bolt://(?!<neo4j-host-or-ip>)|https?://(?!<)"`.
- Verify no secrets are committed with existing repository checks.

## Related

- [../../AGENTS.md](../../AGENTS.md)
- [../../00-vision/01-ontology.ttl](../../00-vision/01-ontology.ttl)
- [../../../03-research/04-standards/01-naming-conventions/case-and-prefix-options.md](../../../03-research/04-standards/01-naming-conventions/case-and-prefix-options.md)

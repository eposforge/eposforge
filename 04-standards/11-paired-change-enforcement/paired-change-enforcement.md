---
doc_kind: standard
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Paired-Change Enforcement

## Status

- draft: 2026-07-19
- supersedes: none
- related: Component 2 (Living Spec), Component 9 (Source Control + CI),
  Standard 09 (Paired Detection), Standard 10 (Ungameable Gates)
- spec-version: n/a

## Scope

This standard defines **how** the paired-change rule is **deterministically
enforced** so Product Living Specs stay current as software changes.

It exists because:

- Declarative intent in → working software out requires intent (Living
  Spec) to remain true as the product develops.
- Without non-bypassable gates, Living Specs rot and **code becomes the
  only accurate process description** (the WiseTech failure mode).
- **Ceremony** (full Spec Kit specify → plan → tasks) may scale with
  ambiguity and size; **Spec fidelity must not**. Every change that
  affects product meaning updates the Product Living Spec (or records a
  narrow, audited exemption that meaning did not change).

This standard does **not** require a risk-tiered Spec Kit clone. It
requires CI machinery and product registry that make unmarked code-only
product changes unmergeable.

**Out of scope:** graded qualitative rubrics (EF-050); kernel ratchets
(Standard 09); full ungameable DoD loop (Standard 10) — those complement
this gate, they do not replace it.

## Normative requirements

### 1. Product registry (Layer A — deterministic)

Every Product (and every platform capability that uses Living Specs)
MUST be registered in a versioned factory config (e.g. `products.toml`
or equivalent under the Adopter Platform Spec / product home) with at
least:

| Field | Meaning |
| --- | --- |
| `product_id` | Stable identity |
| `spec_paths` | Paths that constitute the **current** Living Spec (HEAD), not episode folders |
| `code_globs` | Paths whose change is treated as product fulfillment code |
| `exemption_policy` | Which exemption codes are allowed, by author class (human vs agent) |

CI MUST map every changed file in a PR to zero or more `product_id`s via
this registry. A Product with no registry entry MUST fail CI when its
conventional paths are touched (or the instance MUST treat unregistered
product code as blocked).

### 2. Default paired-change rule (Layer B — deterministic)

For each Product P touched by a change set:

```text
IF  changed_files ∩ code_globs(P)  ≠ ∅
AND changed_files ∩ spec_paths(P)  = ∅
AND no valid exemption for P on this change set
THEN fail CI (paired-change violation)
```

**Default is fail-closed:** product code cannot merge without a Spec path
change unless an explicit exemption applies.

### 3. Exemptions (narrow, audited — not “low risk”)

Exemptions MAY exist only as a **finite allowlist** of codes, for example:

| Code | Intended use |
| --- | --- |
| `paired-change:pure-refactor` | Observable product meaning unchanged (rename, structure only) |
| `paired-change:tooling-only` | Build/CI/tooling under code_globs with no product behavior change |
| `paired-change:spec-home-move` | Mechanical Spec path move with content preserved (rare) |

Requirements:

1. Exemption MUST be declared on the change set (commit trailer and/or PR
   label matching the allowlist exactly).
2. Free-text excuses (e.g. “small fix”, “low risk”) MUST NOT satisfy the
   gate.
3. Every granted exemption MUST emit an Audit & Observability event
   (who, product_id, code, change ref).
4. Agent Policy MUST restrict which codes agents may use; pure-refactor
   for agents SHOULD require Spec-derived tests green (Layer C) and MAY
   require human tier for large diffs.
5. Instances SHOULD rate-limit or review exemption volume per product.

### 4. Spec-derived tests (Layer C)

Instances MUST maintain automated tests linked to Living Spec observable
behavior, inputs/outputs, and bounds (see Component 9). Requirements:

1. Tests MUST assert product outcomes, not only internal implementation
   details an agent can rewrite away (align with Standard 09 altitude and
   Standard 10 where the suite is the DoD gate).
2. CI MUST run these tests on PRs that touch `code_globs` or `spec_paths`
   for that Product.
3. A `pure-refactor` exemption MUST NOT pass if Spec-derived tests fail.
4. Spec lint SHOULD fail when required Spec sections lack any linked
   test identifier or are empty of testable behavior (instance-defined
   minimum).

Full semantic proof that Spec text “adequately narrates” every line of
code is not required. **Enforcement targets the change surface and
declared promises**, not undecidable full Spec↔code equivalence.

### 5. Spec Graph re-projection (Layer D)

On merge that changes `spec_paths` for a Product, CI or post-merge hooks
MUST trigger Spec Graph re-projection for the owning scope (Component 6).
Failure of re-projection MUST be visible (fail check or alert per
instance SLA). This keeps the query surface honest when Spec *is*
updated; it does not replace Layers A–C.

### 6. Non-bypassable merge policy

1. Paired-change, Spec lint (if used), and Spec-derived product tests
   MUST be **required** status checks on protected branches for product
   work.
2. Agent-authored changes MUST NOT dismiss or skip these checks.
3. Human admin bypass, if any, MUST be Audit-logged and SHOULD be
   forbidden for agent-attributed commits by policy.
4. Dev Products MUST land product work only through the forge/CI path
   (Tool Transport → Source Control), not via unaudited direct pushes
   that skip checks.

### 7. Ceremony vs fidelity

| Path | When | Still required |
| --- | --- | --- |
| **Light** | Clarification, bug, edge case, small feature | Edit **same** Product Living Spec (HEAD) + code in one change set; pass Layers A–C |
| **Heavy** | Large or ambiguous work | Optional authoring Adapter (e.g. Spec Kit-style episode) **then fold into** Product Living Spec; episodes are not SoT; gate still applies to fold-in + code |

Instances MUST NOT treat “full specify pipeline” as the only way to
satisfy paired-change. Instances MUST NOT treat “skip Spec for small
work” as valid.

### 8. Intent vs implementation (default to Spec)

When unsure whether a change alters product meaning:

- **MUST update** the Product Living Spec if the prior Spec would become
  false or incomplete as a description of the product.
- **MAY omit** Spec text change only under a valid exemption when
  observable meaning is unchanged (e.g. pure refactor), with Layer C
  still green.

Continuous refinement of the Living Spec is normal product development,
not a separate optional documentation track.

## Minimal Adapter shape

A conforming Source Control + CI + Living Spec enforcement Adapter
implements at least:

1. Versioned **product registry** (Layer A).  
2. CI job **`paired-change`** implementing the default rule and exemption
   allowlist (Layer B).  
3. CI job **`spec-tests`** (and optional **`spec-lint`**) (Layer C).  
4. Branch protection requiring those checks.  
5. Post-merge Spec Graph trigger (Layer D).  
6. Audit events for violations blocked and exemptions granted.  
7. Documented light-path workflow for agents: edit Product Spec + code;
   no requirement to open a new episode folder for every fix.

## Conformance

An instance conforms when:

- [ ] Every active Product is in the registry with `spec_paths` and
      `code_globs`.
- [ ] A PR that changes only product code (no Spec path, no exemption)
      fails required CI.
- [ ] A PR that changes product code and Product Living Spec can pass
      paired-change (subject to tests).
- [ ] Exemption codes are finite, exact-match, and audited.
- [ ] Agents cannot merge by skipping required checks.
- [ ] Spec-derived tests run on product PRs; pure-refactor fails if they
      fail.
- [ ] Spec path merges trigger Spec Graph re-projection.

## Related

- [../../01-architecture/02-components/living-spec.md](../../01-architecture/02-components/living-spec.md)
  — Product Living Spec; paired-change rule.
- [../../01-architecture/02-components/source-control-ci.md](../../01-architecture/02-components/source-control-ci.md)
  — where the gate runs.
- [../../01-architecture/02-components/spec-graph.md](../../01-architecture/02-components/spec-graph.md)
  — projection of current Living Specs only.
- [../09-paired-detection/paired-detection.md](../09-paired-detection/paired-detection.md)
  — ship a check with a fix (sibling discipline).
- [../10-ungameable-gate/ungameable-gate.md](../10-ungameable-gate/ungameable-gate.md)
  — DoD altitude and anti-gaming for acceptance suites.
- [../../01-architecture/02-components/agent-policy.md](../../01-architecture/02-components/agent-policy.md)
  — who may use which exemption codes.
- [../../01-architecture/02-components/audit-observability.md](../../01-architecture/02-components/audit-observability.md)
  — exemption and gate audit events.

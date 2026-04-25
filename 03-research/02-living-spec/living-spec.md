# Living Spec — Implementation Catalog

> **Snapshot date:** 2026-04. Verify current details before adopting.

Candidate approaches for the Living Spec slot
([../../01-architecture/02-components/02-living-spec.md](../../01-architecture/02-components/02-living-spec.md)).
A Living Spec Adapter defines the canonical spec format, enforces the
paired-change rule in CI, and produces a projection consumable by the
Spec Graph.

This catalog is **not exhaustive** and **not an endorsement**.

---

## How to read this catalog

Each entry includes (where known):

- **Format** — the document format (Markdown, YAML, structured schema, etc.).
- **Paired-change check** — how the rule is enforced in CI.
- **Test derivability** — whether the format supports mechanical
  derivation of equivalence classes and boundary values.
- **Notes** — anything notable for Adapter authors.

---

## Living Spec Formats

### SPEC.md (Markdown, structured sections)

- **Format:** Markdown with required sections (`## Purpose`,
  `## Observable Behavior`, `## Inputs / Outputs`,
  `## Non-Functional Bounds`, `## Dependencies`,
  `## Versioning Policy`).
- **Paired-change check:** a CI script diffs the PR against the base
  branch; if any non-spec file changes behavior-relevant paths and
  `SPEC.md` is unchanged, the check fails.
- **Test derivability:** medium. Sections must be filled in with
  machine-parseable constraints (e.g., typed input ranges, explicit
  error conditions) for EP+BVA derivation to be mechanical.
- **Notes:** simplest to adopt; works in any repo without additional
  tooling. Parseable by LLMs for automated test generation.

### OpenAPI / AsyncAPI as Living Spec

- **Format:** OpenAPI 3.x (REST) or AsyncAPI 3.x (event-driven).
- **Paired-change check:** schema diff on the spec file; breaking
  changes fail CI (tools: `oasdiff`, `optic`, `spectral`).
- **Test derivability:** high. Input schemas and response schemas
  directly yield equivalence partitions; `minimum`, `maximum`,
  `minLength`, `maxLength`, `enum`, and `pattern` fields give boundary
  values mechanically.
- **Notes:** strong fit for factory components that expose HTTP or
  event-bus interfaces. Combine with a contract-test runner (see
  below) to validate the implementation against the spec automatically.

### JSON Schema / TypeSpec

- **Format:** JSON Schema draft 7+ or Microsoft TypeSpec.
- **Paired-change check:** schema diff; breaking-change detection via
  `json-schema-diff` or TypeSpec's built-in versioning.
- **Test derivability:** high. Same derivability story as OpenAPI
  (OpenAPI is generated from TypeSpec).
- **Notes:** TypeSpec is useful when the same schema must emit
  multiple representations (OpenAPI, Protobuf, JSON Schema). Good fit
  for factories that serve multiple protocol Adapters from one spec.

---

## Test Derivability Tooling (EP + BVA)

These tools help derive and execute black-box test cases from a Living
Spec's declared inputs/outputs and non-functional bounds. Unit tests
are out of scope — these target the factory-level integration harness.

### Hypothesis (Python)

- **Website:** https://hypothesis.readthedocs.io
- **Cost tier:** free OSS (MPL 2.0).
- **Approach:** property-based testing. You declare input constraints;
  Hypothesis generates equivalence-class representatives and
  aggressively explores boundary values automatically.
- **Notes:** well-suited when Living Specs are expressed in JSON
  Schema (use `hypothesis-jsonschema` to generate inputs directly from
  the schema). Pairs naturally with Testcontainers for real-service
  integration runs.

### QuickCheck (Haskell) / fast-check (TypeScript) / FsCheck (.NET)

- **Website:** https://fast-check.dev (TS); https://fscheck.github.io (\.NET).
- **Cost tier:** free OSS.
- **Approach:** property-based testing, same philosophy as Hypothesis.
- **Notes:** `fast-check` is the TypeScript / Node.js equivalent;
  `FsCheck` covers .NET factories. Choose based on the language of
  the integration harness.

### Pairwise / combinatorial test generators

- **PICT (Microsoft):** https://github.com/microsoft/pict — free,
  generates pairwise-covering input sets from a parameter file.
  Reduces test-case count by orders of magnitude for multi-parameter
  specs.
- **AllPairs / jenny:** lightweight CLI tools for combinatorial
  input generation.
- **Notes:** useful when the Living Spec declares many independent
  input parameters. PICT takes a simple text model and emits a
  covering test matrix; wire it into CI to generate test inputs at
  build time.

### Schemathesis

- **Website:** https://schemathesis.readthedocs.io
- **Cost tier:** free OSS (MIT).
- **Approach:** property-based API testing driven directly from
  OpenAPI / GraphQL schemas. Automatically generates and runs
  requests covering valid, invalid, and boundary input classes.
- **Notes:** strongest fit when the Living Spec is an OpenAPI document.
  Can run inside a Testcontainers-managed service, giving full
  isolation. Reports schema violations and unexpected 5xx responses.

### Dredd

- **Website:** https://dredd.org
- **Cost tier:** free OSS (MIT).
- **Approach:** contract testing — runs the actual service against the
  OpenAPI / API Blueprint spec and fails on any deviation.
- **Notes:** validates that the implementation matches the spec rather
  than generating exploratory cases. Complementary to Schemathesis:
  Dredd checks contract conformance; Schemathesis explores edge cases.

---

## Contribution

Open a PR adding new entries with the same fields. For Living Spec
format entries, document the paired-change check mechanism and test
derivability. For test tooling entries, document which spec formats are
supported and how the tool integrates with the CI gate.

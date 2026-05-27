---
name: upstream-bug-report
description: File a well-formed bug report against an upstream open-source dependency (GitHub issue). Use when EposForge or one of its adapter dependencies exhibits a reproducible defect that must be fixed upstream, particularly for silent failures, incorrect defaults, or API contract violations that affect ontology grounding, graph correctness, or agent reliability.
---

Files a GitHub issue against a dependency repo on behalf of the EposForge
instance operator. The goal is a report that is concise enough for upstream
maintainers to act on immediately: exact location, minimal reproducer, symptom,
fix options, and a workaround if one exists.

## When to use this skill

Use this skill when you have identified a reproducible defect in an upstream
library or service (not in EposForge itself) that:

- causes **silent failure** — the system appears to succeed but produces wrong
  or empty output (e.g. empty ontology graph, all nodes `ontology_valid: false`)
- violates a **published contract** — hardcoded values, undocumented format
  constraints, swallowed exceptions
- is **confirmed in source** — you have read the relevant upstream source file
  and can cite the exact file, function, and line range

Do not file upstream unless you have verified the defect in source. A log
observation alone is not enough.

## Prerequisites

- `gh` CLI authenticated to GitHub (`gh auth status`)
- Upstream repo is on GitHub and accepts issues (check `Issues` tab is enabled)
- You have the defective upstream file path + approximate line range
- You have a working workaround (or have confirmed none exists)

## Step 1 — Confirm the defect in source

Before drafting, locate the exact upstream source. Use GitHub's web search or
`gh` to find the file:

```bash
gh api repos/{owner}/{repo}/contents/{path} | jq -r '.content' | base64 -d | head -80
```

Or browse via `https://github.com/{owner}/{repo}/blob/main/{path}`.

Confirm:
- the hardcoded / incorrect value is present in the current `main` branch
- no recent commit has already fixed it (`git log` on that file via the GitHub API)
- the issue has not already been filed (`gh issue list --repo {owner}/{repo} --search "keyword"`)

```bash
gh issue list --repo {owner}/{repo} --search "RDFLib format xml" --state open
```

## Step 2 — Draft the report

Use this template. Omit sections that don't apply (e.g. no workaround → remove
that section rather than leaving it blank).

```
## Summary

<One paragraph: what fails, under what condition, and what the silent/wrong
outcome is. Name the component and the trigger.>

## Location

`<file path>` (current `main`), <branch name or function>:

    <exact snippet showing the defective code>

<If there is a correct parallel code path nearby, quote it and contrast.>

## Symptom

<What the operator actually observes: log lines, wrong output, empty results,
`false` flags. Paste real log fragments when possible.>

## Fix options

<Ordered from preferred to acceptable. Be specific about API/stdlib calls.>

- <Preferred fix — e.g. use `rdflib.util.guess_format(filename)`>
- <Acceptable fallback>
- <Minimum viable — hard-error instead of silent failure>

## Workaround

<What operators can do today while waiting for the fix. Include exact code.>
```

## Step 3 — File via `gh`

Use `--body-file -` with a heredoc so multi-line bodies with backticks and code
blocks are not mangled by shell escaping:

```bash
gh issue create \
    --repo {owner}/{repo} \
    --title '{Concise title: component + defect + symptom}' \
    --body-file - <<'EOF'
## Summary
...

## Location
...

## Symptom
...

## Fix options
...

## Workaround
...
EOF
```

Title conventions:
- Lead with the component name (`RDFLibOntologyResolver`, `CogneeRouter`, etc.)
- State the defect as a verb phrase (`hardcodes format="xml" for file-object input`)
- State the symptom briefly at the end (`silently dropping Turtle/N3 ontologies`)
- Keep under ~100 characters

## Step 4 — Record in the EposForge backlog

After filing, add a cross-reference to the relevant backlog item (or create a
new `blocked` item if this defect is blocking EposForge work):

```markdown
- upstream: https://github.com/{owner}/{repo}/issues/{N}
- workaround applied: <yes/no — describe if yes>
```

If a workaround is applied at the instance level (e.g. converting TTL to RDF/XML
before upload), document it in the relevant adapter's README or `cognee.md` under
a `## Known upstream issues` section, with the GitHub issue URL and the expected
fix version once known.

## Step 5 — Verify it was filed

```bash
gh issue view {N} --repo {owner}/{repo}
```

Confirm the issue number, title, and that the body rendered correctly
(especially code blocks).

## Worked example

Issue filed 2026-05-27 against `topoteretes/cognee`:

- **Title:** `RDFLibOntologyResolver hardcodes format="xml" for file-object input, silently dropping Turtle/N3 ontologies`
- **Upstream issue:** https://github.com/topoteretes/cognee/issues/2907
- **Defect:** `RDFLibOntologyResolver.py` — file-object branch calls
  `self.graph.parse(data=content, format="xml")` regardless of actual
  serialization; path-based branch does not force a format.
- **Symptom:** All nodes `ontology_valid: false`, 0 classes / 0 individuals
  in lookup, log storm of `No close match found`.
- **Workaround:** Serialize the ontology as RDF/XML before upload via
  `rdflib.Graph().parse(data=ttl, format="turtle").serialize(format="xml")`.
- **EposForge backlog item:** cross-referenced in the active Cognee adapter
  work tracking.

## Adapting for non-GitHub upstreams

If the upstream tracks issues in a different system (GitLab, Gitea, Jira):

- **GitLab:** `glab issue create --repo {namespace}/{project} --title "..." --description "..."`
- **Gitea:** use the Gitea REST API (`POST /repos/{owner}/{repo}/issues`) or
  the `tea` CLI
- **Jira / Linear:** create via their respective CLIs or APIs; preserve the
  same body structure

In all cases: file the issue URL in the EposForge backlog and document any
workaround in the adapter README before considering the task complete.

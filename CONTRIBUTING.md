# Contributing to EposForge

Thanks for your interest in contributing. EposForge is an open, vendor-agnostic
dark-factory pattern. Contributions of vision refinement, component contracts,
research catalogs, reference adapters, and tooling are all welcome.

## Quick start

1. Open an issue describing what you want to change before opening a PR for
   anything non-trivial. Vision and component-contract changes especially
   benefit from a discussion first.
2. Fork the repo, create a topic branch, make your change.
3. Install repo hooks so local commits run safety checks:

```bash
bash instance/scripts/hooks/install-hooks.sh
```

4. Sign your commits with `git commit -s` (see DCO below).
5. Open a pull request against `main`.

## Developer Certificate of Origin (DCO)

We use the [Developer Certificate of Origin](https://developercertificate.org/)
for contributions. There is no CLA. By signing off on a commit, you are
asserting that you wrote the code (or have the right to submit it under the
project's license) and agree to the terms of the DCO.

To sign off, configure your `git` user once:

```bash
git config user.name "Your Name"
git config user.email "you@example.com"
```

Then sign off on each commit:

```bash
git commit -s -m "Your commit message"
```

This appends a line to your commit message:

```text
Signed-off-by: Your Name <you@example.com>
```

PRs without sign-off will be asked to amend. We do not merge unsigned commits.

## What kinds of contributions fit

**Welcome:**

- Sharpening component contracts so they better describe slots without
  locking in implementations.
- Adding entries to research catalogs in `03-research/` (with citations).
- Vision and glossary refinements that improve clarity.
- Reference adapter examples (clearly labeled as examples, not the canonical
  choice).
- Editorial fixes — typos, broken links, structural improvements.

**Probably out of scope:**

- "EposForge should require X" changes that lock the project to a specific
  vendor or protocol. The project is vendor-agnostic by design.
- Code that lives more naturally as an adapter in someone's instance repo.

## Style

- Markdown, line length around 80 columns where reasonable.
- Use [text](path) link syntax for cross-references.
- Match the existing tone: direct, honest about state, opinionated about
  separation of pattern vs implementation.

## License

By contributing, you agree that your contributions will be licensed under
the Apache License, Version 2.0. See [LICENSE](./LICENSE).

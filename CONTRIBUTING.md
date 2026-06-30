# Contributing to EposForge

Thanks for your interest in contributing. EposForge is an open, vendor-agnostic
dark-factory pattern. Contributions of vision refinement, component contracts,
research catalogs, reference adapters, and tooling are all welcome.

## Quick start

1. Open an issue describing what you want to change before opening a PR for
   anything non-trivial. Vision and component-contract changes especially
   benefit from a discussion first.
2. Fork the repo, create a topic branch, make your change.
3. Install repo hooks so local commits run safety checks. This composes all
   per-component hook fragments (see AGENTS.md §Conventions) into
   `.git/hooks/`. Run once per clone, per host (Linux and Windows Git Bash
   both work):

```bash
bash .eposforge/source-control-ci/github-and-actions/scripts/install-hooks.sh
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

## Cryptographically Signed Commits (Required)

DCO sign-off (above) asserts authorship in the commit *message*; it is not
cryptographic. We additionally require every commit to be **cryptographically
signed** so GitHub shows the green **Verified** badge and the provenance of each
commit is verifiable. We use SSH commit signing — the same SSH key you already
use to push can sign commits, with no GPG setup.

Run the one-time setup script for your platform (it only writes your local
`git config` — it never touches a remote):

```bash
# Linux / macOS / Git Bash
bash .eposforge/source-control-ci/github-and-actions/scripts/setup-signed-commits.sh
```

```powershell
# Windows PowerShell
instance\installed\source-control-ci\github-and-actions\scripts\setup-signed-commits.ps1
```

The script configures `gpg.format ssh`, points `user.signingkey` at your public
key, and turns on `commit.gpgsign`/`tag.gpgsign`. It also adds a convenience
alias so a single command signs off **and** signs each commit:

```bash
git config alias.ci 'commit -s -S'   # the script sets this globally for you
git ci -m "Your commit message"      # -s = DCO sign-off, -S = cryptographic sign
```

After running the script, upload the **same** public key to GitHub a second
time as a **Signing key** (it is separate from your Authentication key):
[github.com/settings/ssh/new](https://github.com/settings/ssh/new) → Key type
**Signing key**. Then verify with a test commit — `git log --show-signature`
should report a good signature, and the commit shows **Verified** on GitHub.

### Fixing a PR that fails the check

If the **DCO Check** or signature check fails, re-sign the offending commits and
force-push the topic branch:

```bash
# Last commit only — re-sign-off and re-sign in place
git commit --amend --signoff -S
git push --force-with-lease origin your-branch-name

# Multiple commits — rewrite the last N to add sign-off (and sign each)
git rebase -i --signoff HEAD~N
git push --force-with-lease origin your-branch-name
```

Always prefer `--force-with-lease` over `--force` so you never clobber a commit
someone else pushed to your branch.

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

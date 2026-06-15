# EF-030 Implementation Plan — DCO + SSH Commit Signing

Source package prepared in `scratchpad/git-signed/` (gitignored; copy to a temp
location if the session is fresh).

---

## Step 1 — Add DCO workflow

Copy `scratchpad/git-signed/dco.yml` → `.github/workflows/dco.yml` as-is.

The workflow uses `tim-actions/get-pr-commits@master` + `tim-actions/dco@master`,
triggers on `pull_request` (opened, synchronize, reopened), checks out with
`fetch-depth: 0`, and verifies every commit in the PR has a `Signed-off-by:`
trailer. The job `name:` is already `DCO Check` — do not change it; that string
must match the branch-protection status-check name exactly.

## Step 2 — Update CONTRIBUTING.md

The existing `CONTRIBUTING.md` already covers DCO sign-off. Add a
**Cryptographically Signed Commits (Required)** section drawn from
`scratchpad/git-signed/CONTRIBUTING.md`:

- Explain SSH signing and the green **Verified** badge
- Document the `git ci` alias (`commit -s -S`)
- Add the fix workflow for failed PR checks:

```bash
# Amend last commit
git commit --amend --signoff -S

# Force push safely
git push --force-with-lease origin your-branch-name

# Multiple commits — interactive rebase
git rebase -i --signoff HEAD~N
```

Preserve all existing EposForge-specific content (hook install, what fits,
style, license).

## Step 3 — Add setup scripts

Place two new files under
`instance/installed/09-source-control-ci/github-and-actions/scripts/`:

### `setup-signed-commits.sh` (bash / Git Bash)

Adapted from `scratchpad/git-signed/setup-local.sh`:

1. Detect `~/.ssh/id_ed25519.pub` → fallback `~/.ssh/id_rsa.pub`; exit with
   instructions if neither exists
2. `git config --global gpg.format ssh`
3. `git config --global user.signingkey "$SSH_KEY"`
4. `git config --global commit.gpgsign true`
5. `git config --global tag.gpgsign true`
6. `git config --global alias.ci 'commit -s -S'`
7. `git config --global rebase.autosquash true`
8. `git config --global rebase.autostash true`
9. `git config --global log.showsignature true`
10. `git config --global commit.verbose true`
11. Print next-steps banner: add key at github.com/settings/ssh/new (Key type:
    **Signing key**), then test with `git ci -m "Test signed + DCO commit"`

### `setup-signed-commits.ps1` (PowerShell — Windows)

Same logic, PowerShell syntax:

1. Detect `$env:USERPROFILE\.ssh\id_ed25519.pub` → fallback `id_rsa.pub`
2. Same ten `git config --global` calls via `& git config --global ...`
3. Same next-steps banner

Neither script touches the remote or pushes anything.

## Step 4 — Configure branch protection (operator action — GitHub UI)

**Settings → Branches → Edit rule for `main`:**

- [x] Require a pull request before merging
- [x] Require status checks to pass → add **DCO Check**
- [x] Require signed commits
- [x] Require conversation resolution before merging

Cannot be scripted without an admin-scoped token; must be done by the repo
owner.

## Step 5 — Add SSH signing key to GitHub (operator action — one-time per dev)

github.com/settings/ssh/new → Key type: **Signing key** → paste
`~/.ssh/id_ed25519.pub` contents. Without this step, locally-signed commits
show as "Unverified" on GitHub even though they are cryptographically signed.

## Step 6 — Test

1. Create a topic branch
2. `git ci -m "Test signed + DCO commit"`
3. Push, open a PR
4. Verify: **DCO Check** passes, commit shows **Verified** badge

---

## Deferred (not in EF-030 scope)

- Commit message template (`.gitmessage`) reminding contributors about
  sign-off format
- Pre-commit hook fragment for the hook-composer (`grep "Signed-off-by:"` guard
  before push)
- Policy decision: require signed commits on `main` only vs. all branches

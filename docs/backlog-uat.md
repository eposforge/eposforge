UAT 1 — Lint rule: Status: blocked without an open dep

  This exercises the EF-042 rule. Temporarily append a bad item, run lint, then
  undo.

  cat >> .eposforge/backlog/backlog.md << 'EOF'

  ## Issue EF-999 — UAT test item
  ID: EF-999
  Title: UAT test item
  Date: 2026-06-13
  Status: blocked
  Effort: S
  Fix surface: eposforge-pattern
  Verify with: n/a
  EOF
  bash .eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh

  Expect: error on EF-999 — Status: blocked requires at least one open Depends on:
  item.

  Then remove the item and confirm lint returns to clean:
  # Remove the last 10 lines (the appended item)
  head -n -10 .eposforge/backlog/backlog.md > /tmp/bl.tmp && mv /tmp/bl.tmp
  .eposforge/backlog/backlog.md
  bash .eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh

  ---
  UAT 2 — Lint rule: invalid Theme: value

  # Append to EF-999-style temp item (reuse last approach):
  cat >> .eposforge/backlog/backlog.md << 'EOF'

  ## Issue EF-999 — UAT test item
  ID: EF-999
  Title: UAT test item
  Date: 2026-06-13
  Status: open
  Effort: S
  Fix surface: eposforge-pattern
  Theme: nonexistent-theme
  Verify with: n/a
  EOF
  bash .eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh

  Expect: error — invalid Theme: value not in vocabulary.

  Cleanup:
  head -n -11 .eposforge/backlog/backlog.md > /tmp/bl.tmp && mv /tmp/bl.tmp
  .eposforge/backlog/backlog.md
  bash .eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh

  ---
  UAT 3 — Lint rule: Supersedes: without back-pointer

  cat >> .eposforge/backlog/backlog.md << 'EOF'

  ## Issue EF-999 — UAT test item
  ID: EF-999
  Title: UAT test item
  Date: 2026-06-13
  Status: open
  Effort: S
  Fix surface: eposforge-pattern
  Supersedes: EF-022
  Verify with: n/a
  EOF
  bash .eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh

  Expect two errors:
  1. EF-022 is still open — can't be superseded yet
  2. EF-022 lacks a Superseded by: EF-999 back-pointer

  Cleanup:
  head -n -11 .eposforge/backlog/backlog.md > /tmp/bl.tmp && mv /tmp/bl.tmp
  .eposforge/backlog/backlog.md
  bash .eposforge/backlog/file-based-backlog/scripts/lint-backlog.sh

  ---
  UAT 4 — Portfolio diagram in VS Code preview

  bash .eposforge/backlog/file-based-backlog/scripts/aggregate.sh
  --mermaid

  Then open backlog/portfolio.md in VS Code with Cmd+Shift+V (markdown preview).
  You should see a Mermaid flowchart with an (unanchored) subgraph and a single
  EF-023 → EF-024 edge. All node IDs should be clean EF-XXX format with no colons.

  ---
  UAT 5 — Critical-path against a primary adopter anchor (multi-root)

  BACKLOG_ROOTS="<framework-root>:/path/to/primary-adopter/.eposforge" \
    bash .eposforge/backlog/file-based-backlog/scripts/aggregate.sh
  --critical-path ADOPTER-013

  Expect: a chain ending at the adopter item, with the EF-043 node shown as resolved (not
  open), and the adopter item marked [workable now]. Use generic placeholders.

  ---
  UAT 6 — Skill docs readability

  Open the two new skills and skim for navigability:

  cat skills/milestone-elicitation/SKILL.md | head -60
  cat skills/portfolio-review/SKILL.md | head -60

  Check: does the opening paragraph tell you when to use the skill without reading
  the whole thing? Is Step 1 actionable without prior context?

  ---
  UAT 7 — new-issue.sh next-ID check (read-only look)

  Don't run this one outright — it appends to the file. Instead, just verify what
  the next ID would be:

  grep -ohE "EF-[0-9]{3,}" .eposforge/backlog/backlog.md .eposforge/backlog/backlog-slated.md
  .eposforge/backlog/backlog-archive.md | sort -t- -k2 -n | tail -3

  Expect: highest should be EF-043. Next run of new-issue.sh would produce EF-044.

  ---
  UAT 8 — Version-stamped sync to an adopter (EF-035)

  Exercises sync-tooling.sh drift detection and copy. Uses a throwaway sandbox
  adopter under /tmp so nothing real is touched. (No on-disk adopter currently
  vendors the scripts — a primary adopter may be data-only in some setups — so a sandbox is the way to test this.)

  SRC=.eposforge/backlog/file-based-backlog/scripts
  SANDBOX=/tmp/uat-adopter
  DEST=$SANDBOX/.eposforge/backlog/file-based-backlog/scripts
  rm -rf "$SANDBOX" && mkdir -p "$DEST"
  cp "$SRC"/*.sh "$DEST"/ && cp "$SRC"/VERSION "$DEST"/
  echo "0.1.0" > "$DEST"/VERSION                        # make version stale
  echo "# drift" >> "$DEST"/lint-backlog.sh             # make one file differ
  rm -f "$DEST"/ready.sh                                # make one file missing
  # (hooks/ is absent too, exercising the directory path)

  # 1) Drift report — expect MISSING ready.sh, MISSING hooks, DIFFERS lint/VERSION; exit 1
  bash "$SRC"/sync-tooling.sh --check "$SANDBOX"

  # 2) Real sync — expect every file incl. hooks copied, no cp error, "now at <VERSION>"; exit 0
  bash "$SRC"/sync-tooling.sh "$SANDBOX"

  # 3) Re-check — expect "Target is up to date"; exit 0
  bash "$SRC"/sync-tooling.sh --check "$SANDBOX"

  # Confirm hooks/ propagated and ready.sh is back+executable, then clean up
  test -f "$DEST"/hooks/pre-commit && echo "hooks ok"
  test -x "$DEST"/ready.sh && echo "ready.sh ok"
  rm -rf "$SANDBOX"

  Note: sync-tooling.sh only MAINTAINS an existing install — it errors if the
  target scripts/ directory is missing. Bootstrapping a brand-new adopter still
  requires an initial manual copy (mkdir -p + cp -r) before --check/sync apply.
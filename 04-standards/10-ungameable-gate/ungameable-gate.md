---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Standard 10: Ungameable Gates and the Definition of Done

This standard guides adopters to establish the highest-altitude integration tests as the task-completion gate in their EposForge platform. It resolves the core tension between giving agents visibility into test failures for iteration, while preventing agents from gaming those tests.

## Definition of Done
A task may be declared DONE only when the ungameable gate passes. A task may never be declared done based on agent self-report.

## The 5 Anti-Gaming Requirements

To ensure agents cannot game the verification process, integration tests must satisfy these five requirements:

1. **Write Scope Separation:** Test definitions and acceptance criteria must live OUTSIDE the implementing agent's write scope. The agent that writes the code may not edit the gate that judges it.
2. **Spec-Derived Tests:** Tests must be derived directly from the [Living Spec]'s declared acceptance criteria, not reverse-engineered from the implementation.
3. **Outcome Altitude:** The gate must verify the real OUTCOME end-to-end at the behavioral/integration altitude, not narrow proxies an agent can satisfy trivially or hardcode.
4. **Tamper-Evidence:** Test definitions must carry tamper-evidence or provenance so that any unauthorized edits are immediately detectable by [Audit & Observability].
5. **Held-Out Assertions:** Optional held-out assertions that the agent cannot see should be used to prevent overfitting to the exposed test cases.

## The Iteration Loop

The EposForge framework wires these tests directly into the agent iteration loop:

1. **Dispatch:** The [Orchestrator] dispatches the task.
2. **Execute:** The [Execution Sandbox] runs the agent (a [Dev Product]).
3. **Run Gate:** The integration tests are executed against the output.
4. **Diagnose & Fix:** The results and diagnostics are exposed back to the agent so it can fix issues.
5. **Re-run:** The loop repeats until the gate passes.

This loop resolves the explicit loop-visibility-vs-ungameable tension: the agent must SEE results to iterate, but must not hold mutate rights over the gate, and held-out assertions cover the overfit case.

## Durable Enforcement

Finally, the [Source Control + CI] component enforces the same gate as a required PR status check. This provides the durable, post-loop enforcement that prevents unverified work from entering the main branch. See `01-architecture/02-components/source-control-ci.md` for details.

These rules run *in a runner*. The named sub-contract
[Test runner](../../01-architecture/02-components/source-control-ci-test-runner.md)
is the slot those rules occupy — one command, clone-local, not a
mandated vendor. Kernel one-command detection is a property of that
runner, not a second harness. The cross-agent review contract is not
the runner: standing properties live in the tree and run with no review
payload. See the
[candidate catalog](../../03-research/01-architecture/02-components/source-control-ci/test-runners.md).

## Declaring Done When There Is No Gate

The rules above define when a task **is** done. They assume the gate already
exists. Much real work — an interactive session with an operator, a fix made
before any acceptance suite covers the changed behavior — happens where no
gate exists yet, and that is exactly where the self-declared-done failure
occurs. This section governs the **claim**, not the state.

6. **A done claim carries its evidence.** An agent declaring work done MUST
   name the command it ran, MUST have run it as part of this task, and MUST
   show the result. A claim with no command behind it is not a done claim; it
   is a progress report and MUST be worded as one.
7. **No gate, no done.** Where no gate covers the changed behavior, the agent
   MUST NOT declare the task done. It MUST state what it changed and what it
   could not verify. Building the missing check is part of the task, not
   follow-up work — see
   [Paired Detection](../09-paired-detection/paired-detection.md) requirement 1.
   The absence of a runnable check is the finding, not an excuse.
8. **A proxy is not the outcome.** None of the following is evidence that work
   is done, and an agent MUST NOT offer any of them as one:
   - a linter, formatter, or schema validator passing — these check shape, not
     behavior;
   - a build, compile, or type-check succeeding;
   - a commit, branch, or pull request whose title or message names the task;
   - a service, container, or process reporting itself healthy, running, or up;
   - a check exercised only on well-formed input, never on the malformed case
     it exists to reject;
   - a suite that passes because the condition it tests cannot yet arise — for
     example, assertions over a configuration file no instance has;
   - a test derived from the implementation rather than from the declared
     acceptance criteria (Anti-Gaming Requirement 2);
   - the implementing agent re-reading its own diff and judging it correct.

   These share one shape: a cheap signal standing in for the outcome, believed
   because it was green. Offering one is reward hacking in its plainest form —
   optimizing the measurement instead of the result — and it is the same failure
   the Anti-Gaming Requirements above prevent inside a gate, surfacing here in
   the report rather than in the test. The list is illustrative, not exhaustive;
   a signal belongs on it whenever it can pass while the declared outcome fails.
9. **The claim rule lives in loaded context.** An adopting repository's
   always-loaded agent instructions (`AGENTS.md` or its equivalent) MUST carry
   a condensed statement of requirements 6–8. A standard that is only read
   when someone goes looking for it does not reach the moment the claim is
   made; this file remains the source of truth.

## Conformance

- The always-loaded agent instructions carry the condensed claim rule:
  `rg "done claim" AGENTS.md`
- Review signal: a completion message names a command and its result, or
  states plainly that the change is unverified and why. A message that reports
  a proxy from requirement 8 as if it settled the outcome is rejected.
- A change that fixes a defect and lands no re-runnable check is rejected —
  the [Paired Detection](../09-paired-detection/paired-detection.md) standard's
  conformance applies here unchanged.

<!-- component-links (generated by check-component-links.py --write-defs) -->
[Living Spec]: ../../01-architecture/02-components/living-spec.md
[Audit & Observability]: ../../01-architecture/02-components/audit-observability.md
[Orchestrator]: ../../01-architecture/02-components/orchestrator.md
[Execution Sandbox]: ../../01-architecture/02-components/execution-sandbox.md
[Dev Product]: ../../01-architecture/02-components/dev-product.md
[Source Control + CI]: ../../01-architecture/02-components/source-control-ci.md

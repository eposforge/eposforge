# Standard 10: Ungameable Gates and the Definition of Done

This standard guides adopters to establish the highest-altitude integration tests as the task-completion gate in their EposForge platform. It resolves the core tension between giving agents visibility into test failures for iteration, while preventing agents from gaming those tests.

## Definition of Done
A task may be declared DONE only when the ungameable gate passes. A task may never be declared done based on agent self-report.

## The 5 Anti-Gaming Requirements

To ensure agents cannot game the verification process, integration tests must satisfy these five requirements:

1. **Write Scope Separation (C8):** Test definitions and acceptance criteria must live OUTSIDE the implementing agent's write scope. The agent that writes the code may not edit the gate that judges it.
2. **Spec-Derived Tests (C1):** Tests must be derived directly from the Living Spec's declared acceptance criteria (Component 1), not reverse-engineered from the implementation.
3. **Outcome Altitude:** The gate must verify the real OUTCOME end-to-end at the behavioral/integration altitude, not narrow proxies an agent can satisfy trivially or hardcode.
4. **Tamper-Evidence (C11):** Test definitions must carry tamper-evidence or provenance so that any unauthorized edits are immediately detectable by the Audit Log component (C11).
5. **Held-Out Assertions:** Optional held-out assertions that the agent cannot see should be used to prevent overfitting to the exposed test cases.

## The Iteration Loop

The EposForge framework wires these tests directly into the agent iteration loop:

1. **Dispatch:** The Orchestrator (Component 4) dispatches the task.
2. **Execute:** The execution environment (Component 3) runs the agent.
3. **Run Gate:** The integration tests are executed against the output.
4. **Diagnose & Fix:** The results and diagnostics are exposed back to the agent so it can fix issues.
5. **Re-run:** The loop repeats until the gate passes.

This loop resolves the explicit loop-visibility-vs-ungameable tension: the agent must SEE results to iterate, but must not hold mutate rights over the gate, and held-out assertions cover the overfit case.

## Durable Enforcement

Finally, the Source Control & CI component (Component 9) enforces the same gate as a required PR status check. This provides the durable, post-loop enforcement that prevents unverified work from entering the main branch. See `01-architecture/02-components/source-control-ci.md` for details.
